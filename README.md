# fzf-tab

Replace zsh's default completion selection menu with fzf!

<img width="70%" src="http://storage.aloxaf.cn/fzf-tab.gif?v=2">

<img width="70%" src="http://storage.aloxaf.cn/fzf-tab.webp">

## Install

### Manual

First, clone this repository
```bash
git clone https://github.com/Aloxaf/fzf-tab ~/somewhere
```

Then add the following line to your `~/.zshrc`
```bash
source ~/somewhere/fzf-tab.plugin.zsh
```

### Antigen

```bash
antigen bundle Aloxaf/fzf-tab
```

### Zplugin

```bash
zplugin light Aloxaf/fzf-tab
```

### Oh-My-Zsh

Clone this repository to your custom directory and then add `fzf-tab` to your plugin list.

```bash
git clone https://github.com/Aloxaf/fzf-tab ~ZSH_CUSTOM/plugins/fzf-tab
```

## Usage

Just press TAB as usual~

Some useful commands:

- `disable-fzf-tab`: Use it when you come across some bugs

- `enable-fzf-tab`: Use it when fzf-tab doesn't initialize properly.

### Configure

#### `FZF_TAB_COMMAND`

The fuzzy search program, default value: `fzf`

#### `FZF_TAB_OPTS`

Parameters of fuzzy search program.

Defualt value:

```bash
FZF_TAB_OPTS=(
    --ansi --color=hl:255  # Enable ANSI color support, necessary for showing groups
    --nth=2,3 -d '\0'      # Don't search FZF_TAB_PREFIX
    --layout=reverse --height=90%
    --tiebreak=begin --bind=tab:down,ctrl-j:accept,change:top --cycle
    '--query=$query'       # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)
```

**NOTE:** If `zstyle ':completion:*:descriptions' format` is not set, `--color=hl:255` will be removed.

#### `FZF_TAB_INSERT_SPACE`

Whether to automatically insert a whitespace after the result, default value: `1`

#### `FZF_TAB_QUERY`

The strategy for generating query string, defualt value: `(prefix input first)`

Possible values:

- `input`: use user's input as query string, just like zsh's defualt behavior
- `prefix`: use the longest common prefix for all candidates as the query string
- `first`: just a flag. If set, the first valid query string will be use
- `longest`: another flag. If set, the longest valid query string will be use

#### `FZF_TAB_GROUP`

When `zstyle ':completion:*:descriptions' format` is set, fzf-tab will display these group descriptions as headers.

Set to `full` to show all descriptions, set to `brief` to only show descriptions for groups with duplicate members.

Defualt value: full

#### `FZF_TAB_PREFIX`

A prefix to indicate the color, default value: `·`

**NOTE:** If not set `zstyle ':completion:*:descriptions' format`, it will be set to empty.

#### `FZF_TAB_GROUP_COLOR`

Color of different group and their descriptions.

Default value:

```bash
FZF_TAB_GROUP_COLOR=(
    $'\033[36m' $'\033[33m' $'\033[35m' $'\033[34m' $'\033[31m' $'\033[32m' \
    $'\033[93m' $'\033[38;5;21m' $'\033[38;5;28m' $'\033[38;5;094m' $'\033[38;5;144m' $'\033[38;5;210m'
)
```

**NOTE:** If not set `zstyle ':completion:*:descriptions' format`, it will be set to white.

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
