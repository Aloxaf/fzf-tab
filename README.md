# fzf-tab

Replace zsh's default completion selection menu with fzf!

[![asciicast](https://asciinema.org/a/293849.svg)](https://asciinema.org/a/293849)

# Install

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

## Zplugin

```zsh
zplugin light Aloxaf/fzf-tab
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

## Custom completions

There exists mechanism for overwriting completion action for particular command
[similar to fzf](https://github.com/junegunn/fzf/wiki/Examples-(completion)).
If function named `_fzf_complete_foo` is found, it will be used for handling completions
of `foo` command.

If you also have [fzf's completions](https://github.com/junegunn/fzf#fuzzy-completion-for-bash-and-zsh)
enabled (`completion.zsh` is sourced), you can use it's `_fzf_complete` helper function, for example:

```zsh
_fzf_complete_foo() {
  _fzf_complete "--multi --reverse" "$@" < <(
    echo foo
    echo bar
    echo bazz
  )
}
```

## Configure

### Variables

Here are some variables which can be used to control the behavior of fzf-tab.

#### `FZF_TAB_COMMAND`

The fuzzy search program, default value: `fzf`

#### `FZF_TAB_OPTS`

Parameters of the fuzzy search program.

Default value:

```zsh
FZF_TAB_OPTS=(
    --ansi   # Enable ANSI color support, necessary for showing groups
    --expect='$FZF_TAB_CONTINUOUS_TRIGGER' # For continuous completion
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\0'  # Don't search FZF_TAB_PREFIX
    --layout=reverse --height='${FZF_TMUX_HEIGHT:=75%}'
    --tiebreak=begin -m --bind=tab:down,ctrl-j:accept,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)
```

#### `FZF_TAB_PREFIX`

A prefix to indicate the color, default value: `·`

**NOTE:** If not set `zstyle ':completion:*:descriptions' format`, it will be set to empty.

#### `FZF_TAB_NO_GROUP_COLOR`

Color when there is no group, default value: `$'\033[37m'` (white)

#### `FZF_TAB_SINGLE_GROUP`

The setting when there is only one group, default value: `(color header)`

Possible values:

- `prefix`: show `$FZF_TAB_PREFIX`
- `color`: show group color
- `header`: show group header

#### `FZF_TAB_GROUP_COLORS`

Color for different groups and their descriptions.

Default value:

```zsh
FZF_TAB_GROUP_COLORS=(
    $'\033[94m' $'\033[32m' $'\033[33m' $'\033[35m' $'\033[31m' $'\033[38;5;27m' $'\033[36m' \
    $'\033[38;5;100m' $'\033[38;5;98m' $'\033[91m' $'\033[38;5;80m' $'\033[92m' \
    $'\033[38;5;214m' $'\033[38;5;165m' $'\033[38;5;124m' $'\033[38;5;120m'
)
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

#### `FZF_TAB_CUSTOM_COMPLETIONS`

Whether to search for custom completion functions. Default value: `1`

#### `FZF_TAB_CUSTOM_COMPLETIONS_PREFIX`

Default value: `"_fzf_complete_"`

note: The default value matches fzf name convention so that the same functions can be used both by fzf and fzf-tab.

### Zstyle

zstyle can give you more control over fzf-tab's behavior, eg:

```
# disable sort when completing options of any command
zstyle ':fzf_tab:complete:*:options' sort false

# use input as query string when completing zlua
zstyle ':fzf_tab:complete:_zlua:*' query-string input
```

zstyle is set via command like this: `zstyle ':fzf_tab:{context}' tag value`.
See [zsh's doc](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fzutil-Module) for more information.

You can use <kbd>C-x h</kbd> to get possible context for a command:
Note: This command will break fzf-tab totally, you need to restart zsh to re-enable fzf-tab.

```zsh
❯ rg -- # Press `C-x h` here
tags in context :completion::complete:rg::
    operand-argument-1 options  (_arguments _rg _ripgrep)
tags in context :completion::complete:rg:options:
    options  (_arguments _rg _ripgrep)
tags in context :completion::files-enhance:::
    globbed-files  (_files _files_enhance)
```

Here are avaiable tags:

#### continuous-trigger

The key to trigger a continuous completion. It's useful when complete a long path.

Default value: `zstyle ':fzf_tab:*' continuous-trigger '/'`

#### fake-compadd

How to do a fake compadd. This only affects the result of multiple selections.

- `default`: Call compadd with an empty string. It will sometimes add extra whitespace if you select multiple results.
- `fakeadd`: Try to deceive the completion system. Sometimes it fails and then leads to unwanted results.
(eg. `sudo git \t` will get not only git subcommands but also local files)

Default value: `zstyle ':fzf_tab:*' fake-compadd default`

#### insert-space

Whether to automatically insert a space after the result.

Default value: `zstyle ':fzf_tab:*' insert-space true`

#### query-string

The strategy for generating query string.

Possible values:

- `input`: use user's input as query string, just like zsh's default behavior
- `prefix`: use the longest common prefix for all candidates as the query string
- `first`: just a flag. If set, the first valid query string will be used
- `longest`: another flag. If set, the longest valid query string will be used

Default value: `zstyle ':fzf_tab:*' query-string prefix input first`

#### show-group

When `zstyle ':completion:*:descriptions' format` is set, fzf-tab will display these group descriptions as headers.

Set to `full` to show all descriptions, set to `brief` to only show descriptions for groups with duplicate members.

Default value: `zstyle ':fzf_tab:*' show-group full`

#### sort

Whether sort the result.

Default value: `zstyle ':fzf_tab:*' sort true`

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
