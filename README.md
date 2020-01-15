# fzf-tab

Replace zsh's default completion selection menu with fzf!

[![asciicast](https://asciinema.org/a/293849.svg)](https://asciinema.org/a/293849)

## Install

### Manual

First, clone this repository

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~/somewhere
```

Then add the following line to your `~/.zshrc`

```zsh
source ~/somewhere/fzf-tab.plugin.zsh
```

### Antigen

```zsh
antigen bundle Aloxaf/fzf-tab
```

### Zplugin

```zsh
zplugin light Aloxaf/fzf-tab
```

### Oh-My-Zsh

Clone this repository to your custom directory and then add `fzf-tab` to your plugin list.

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~ZSH_CUSTOM/plugins/fzf-tab
```

## Usage

Just press <kdb>Tab</kdb> as usual~

fzf-tab uses the default keybindings of fzf, except that <kdb>Tab</kdb> is used to scroll down the completions.
But you can use <kbd>Ctrl</kdb>+<kdb>Space</kbd> to select multiple results.

Available commands:

- `disable-fzf-tab`: Use it when you come across some bugs

- `enable-fzf-tab`: Use it when fzf-tab doesn't initialize properly.

### Configure

Here are some variables which can be used to control the behavior of fzf-tab.

#### `FZF_TAB_COMMAND`

The fuzzy search program, default value: `fzf`

#### `FZF_TAB_OPTS`

Parameters of the fuzzy search program.

Default value:

```zsh
FZF_TAB_OPTS=(
    --ansi   # Enable ANSI color support, necessary for showing groups
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\0'  # Don't search FZF_TAB_PREFIX
    --layout=reverse --height=90%
    --tiebreak=begin -m --bind=tab:down,ctrl-j:accept,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)
```

#### `FZF_TAB_INSERT_SPACE`

Whether to automatically insert a space after the result, default value: `1`

#### `FZF_TAB_QUERY`

The strategy for generating query string, default value: `(prefix input first)`

Possible values:

- `input`: use user's input as query string, just like zsh's default behavior
- `prefix`: use the longest common prefix for all candidates as the query string
- `first`: just a flag. If set, the first valid query string will be used
- `longest`: another flag. If set, the longest valid query string will be used

#### `FZF_TAB_FAKE_COMPADD`

How to do a fake compadd. This variable only affects the result of multiple selections.

- `default`: Call compadd with an empty string. It will sometimes add extra whitespace if you select multiple results.
- `fakeadd`: Try to deceive the completion system. Sometimes it fails and then leads to unwanted results.
(eg. `sudo git \t` will get not only git subcommands but also local files)

#### `FZF_TAB_SHOW_GROUP`

When `zstyle ':completion:*:descriptions' format` is set, fzf-tab will display these group descriptions as headers.

Set to `full` to show all descriptions, set to `brief` to only show descriptions for groups with duplicate members.

Default value: full

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

## Difference from other plugins

fzf-tab doesn't do "complete", it just shows your results of the default completion system.

So it works EVERYWHERE (variables, function names, directory stack, in-word completion, etc.).
And most of your configure for default completion system is still valid.

## Compatibility with other plugins

Some plugins may also bind "^I" to their custom widget, like [fzf/shell/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh) or [ohmyzsh/lib/completion.zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh#L61-L73).

By default, fzf-tab will call the widget previously bound to "^I" to get the completion list. So there is no problem in most cases, unless fzf-tab is initialized before a plugin which doesn't handle the previous binding properly.

So if you find your fzf-tab doesn't work properly, please make sure it is the last plugin to bind "^I" (If you don't know what I mean, just put it to the end of your plugin list).

## Related projects

- https://github.com/lincheney/fzf-tab-completion (fzf tab completion for zsh, bash and GNU readline apps)
