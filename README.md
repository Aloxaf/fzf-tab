# fzf-tab

[![Test](https://github.com/Aloxaf/fzf-tab/workflows/Test/badge.svg)](https://github.com/Aloxaf/fzf-tab/actions?query=workflow%3ATest)
[![GitHub license](https://img.shields.io/github/license/Aloxaf/fzf-tab)](https://github.com/Aloxaf/fzf-tab/blob/master/LICENSE)

Replace zsh's default completion selection menu with fzf!

[![asciicast](https://asciinema.org/a/293849.svg)](https://asciinema.org/a/293849)

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [fzf-tab](#fzf-tab)
- [Install](#install)
    - [Manual](#manual)
    - [Antigen](#antigen)
    - [Zinit](#zinit)
    - [Oh-My-Zsh](#oh-my-zsh)
- [Usage](#usage)
    - [Configure](#configure)
        - [command](#command)
        - [extra-opts](#extra-opts)
        - [continuous-trigger](#continuous-trigger)
        - [ignore](#ignore)
        - [fake-compadd](#fake-compadd)
        - [insert-space](#insert-space)
        - [query-string](#query-string)
        - [prefix](#prefix)
        - [no-group-color](#no-group-color)
        - [single-group](#single-group)
        - [group-colors](#group-colors)
        - [show-group](#show-group)
- [Difference from other plugins](#difference-from-other-plugins)
- [Compatibility with other plugins](#compatibility-with-other-plugins)
- [Related projects](#related-projects)

<!-- markdown-toc end -->

【[中文文档](README_CN.md)】

# Install

**NOTE:** fzf-tab needs to be sourced after `compinit`, but before plugins which will wrap widgets like [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) or [fast-syntax-highlighting](https://github.com/zdharma/fast-syntax-highlighting).

## Manual

First, clone this repository

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~/somewhere
```

Then add the following line to your `~/.zshrc`

```zsh
source ~/somewhere/fzf-tab.plugin.zsh
```

## Antigen

```zsh
antigen bundle Aloxaf/fzf-tab
```

## Zinit

```zsh
zinit light Aloxaf/fzf-tab
```

## Oh-My-Zsh

Clone this repository to your custom directory and then add `fzf-tab` to your plugin list.

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~ZSH_CUSTOM/plugins/fzf-tab
```

# Usage

Just press <kbd>Tab</kbd> as usual~

You can use <kbd>Ctrl</kdb>+<kdb>Space</kbd> to select multiple results,
and <kbd>/</kbd> to trigger continuous completion (useful when complete a deep path).

Available commands:

- `disable-fzf-tab`: Use it when you come across some bugs

- `enable-fzf-tab`: Use it when fzf-tab doesn't initialize properly.

Key Bindings:

- `toggle-fzf-tab`: Use it disable/enable plugin.

For example <kbd>Ctrl</kdb>+<kdb>T</kbd> `bindkey '^T' toggle-fzf-tab`

## Configure

fzf-tab use zstyle for configuration. It can give you more control over fzf-tab's behavior, eg:

```zsh
# disable sort when completing options of any command
zstyle ':completion:complete:*:options' sort false

# use input as query string when completing zlua
zstyle ':fzf-tab:complete:_zlua:*' query-string input

# (experimental, may change in the future)
local extract="
# trim input(what you select)
in=\${\${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
# get ctxt for current completion(some thing before or after the current word)
local -A ctxt=(\"\${(@ps:\2:)CTXT}\")
"

# give a preview of commandline arguments when completing `kill`
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap

# give a preview of directory by exa when completing cd
zstyle ':fzf-tab:complete:cd:*' extra-opts --preview=$extract'exa -1 --color=always ${~ctxt[hpre]}$in'
```

fzf-tab is configured via command like this: `zstyle ':fzf-tab:{context}' tag value`. `fzf-tab` is the top context.
See [zsh's doc](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fzutil-Module) for more information.

You can use <kbd>C-x h</kbd> to get possible context for a command:

**NOTE:** You need to use `enable-fzf-tab` to active fzf-tab again after this command.

```zsh
❯ rg -- # Press `C-x h` here
tags in context :completion::complete:rg::
    operand-argument-1 options  (_arguments _rg _ripgrep)
tags in context :completion::complete:rg:options:
    options  (_arguments _rg _ripgrep)
tags in context :completion::files-enhance:::
    globbed-files  (_files _files_enhance)
```

Here are avaiable tags in `fzf-tab` context:

### command

How to start the fuzzy search program.

Default value:
```zsh
FZF_TAB_COMMAND=(
    fzf
    --ansi   # Enable ANSI color support, necessary for showing groups
    --expect='$continuous_trigger' # For continuous completion
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\x00'  # Don't search prefix
    --layout=reverse --height='${FZF_TMUX_HEIGHT:=75%}'
    --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)
zstyle ':fzf-tab:*' command $FZF_TAB_COMMAND
```

### extra-opts

Extra options for command

Default value: None

### continuous-trigger

The key to trigger a continuous completion. It's useful when complete a long path.

Default value: `zstyle ':fzf-tab:*' continuous-trigger '/'`

### ignore

Don't active fzf-tab in this context.

Default value: `zstyle ':fzf-tab:*' ignore false`

### fake-compadd

How to do a fake compadd. This only affects the result of multiple selections.

- `default`: Call compadd with an empty string. It will sometimes add extra whitespace if you select multiple results.
- `fakeadd`: Try to deceive the completion system. Sometimes it fails and then leads to unwanted results.
(eg. `sudo git \t` will get not only git subcommands but also local files)

Default value: `zstyle ':fzf-tab:*' fake-compadd default`

### insert-space

Whether to automatically insert a space after the result.

Default value: `zstyle ':fzf-tab:*' insert-space true`

### query-string

The strategy for generating query string.

Possible values:

- `input`: use user's input as query string, just like zsh's default behavior
- `prefix`: use the longest common prefix for all candidates as the query string
- `first`: just a flag. If set, the first valid query string will be used
- `longest`: another flag. If set, the longest valid query string will be used

Default value: `zstyle ':fzf-tab:*' query-string prefix input first`

### prefix

A prefix to indicate the color.

Default value: `zstyle ':fzf-tab:*:' prefix '·'`

**NOTE:** If not set `zstyle ':completion:*:descriptions' format`, it will be set to empty.

### no-group-color

Color when there is no group.

Default value: `zstyle ':fzf-tab:*' $'\033[37m'` (white)

### single-group

What to show when there is only one group.

Possible values:

- `prefix`: show color prefix
- `color`: show group color
- `header`: show group header

Default value: `zstyle ':fzf-tab:*' single-group color header`

### group-colors

Color for different groups and their descriptions.

Default value:

```zsh
FZF_TAB_GROUP_COLORS=(
    $'\033[94m' $'\033[32m' $'\033[33m' $'\033[35m' $'\033[31m' $'\033[38;5;27m' $'\033[36m' \
    $'\033[38;5;100m' $'\033[38;5;98m' $'\033[91m' $'\033[38;5;80m' $'\033[92m' \
    $'\033[38;5;214m' $'\033[38;5;165m' $'\033[38;5;124m' $'\033[38;5;120m'
)
zstyle ':fzf-tab:*' group-colors $FZF_TAB_GROUP_COLORS
```

To choose the color you want, you can first use this function to print the palette:

```zsh
# Usage: palette
palette() {
    local -a colors
    for i in {000..255}; do
        colors+=("%F{$i}$i%f")
    done
    print -cP $colors
}
```

And then use this helper function to get escape sequence for the color code:

```zsh
# Usage: printc COLOR_CODE
printc() {
    local color="%F{$1}"
    echo -E ${(qqqq)${(%)color}}
}
```

### show-group

When `zstyle ':completion:*:descriptions' format` is set, fzf-tab will display these group descriptions as headers.

Set to `full` to show all descriptions, set to `brief` to only show descriptions for groups with duplicate members.

Default value: `zstyle ':fzf-tab:*' show-group full`

# Difference from other plugins

fzf-tab doesn't do "complete", it just shows your results of the default completion system.

So it works EVERYWHERE (variables, function names, directory stack, in-word completion, etc.).
And most of your configure for default completion system is still valid.

# Compatibility with other plugins

Some plugins may also bind "^I" to their custom widget, like [fzf/shell/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh) or [ohmyzsh/lib/completion.zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh#L61-L73).

By default, fzf-tab will call the widget previously bound to "^I" to get the completion list. So there is no problem in most cases, unless fzf-tab is initialized before a plugin which doesn't handle the previous binding properly.

So if you find your fzf-tab doesn't work properly, please make sure it is the last plugin to bind "^I" (If you don't know what I mean, just put it to the end of your plugin list).

# Related projects

- https://github.com/lincheney/fzf-tab-completion (fzf tab completion for zsh, bash and GNU readline apps)
