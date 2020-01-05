# fzf-tab

Replace zsh's default completion selection menu with fzf!

![](http://storage.aloxaf.cn/fzf-tab.gif?v=2)

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

```
git clone https://github.com/Aloxaf/fzf-tab ~ZSH_CUSTOM/plugins/fzf-tab
```

## Usage

Just press TAB as usual~

Some variables:

- `FZF_TAB_COMMAND`: The fuzzy search program

- `FZF_TAB_OPTS`: Its parameters

- `FZF_TAB_INSERT_SPACE`: If set, fzf-tab will automatically appending a space after completion.

- `FZF_TAB_QUERY`: Strategy for generating query strings:

    - `input`: just like zsh's default behavior
    - `prefix`: the query string will be the longest common prefix for all matches
    - `first`: with this flag the fisrt valid query string will be use (default)
    - `longest`: with this flag the longest valid query string will be use

  The default value is `(prefix input first)`, which means fzf-tab will first try to find the longest common prefix for all matches, if not found it will use your input.

Some commands:

- `disable-fzf-tab`: Use it when you come across some bugs

- `enable-fzf-tab`: Use it when fzf-tab doesn't initialize properly.

## Difference from other plugins

fzf-tab doesn't do "complete", it just shows your results of the default completion system.

So it works EVERYWHERE (variables, function names, directory stack, in-word completion, etc.).
And most of your configure for default completion system is still valid.

## Compatibility with other plugins

Some plugins may also bind "^I" to their custom widget, like [fzf/shell/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh) or [ohmyzsh/lib/completion.zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh#L61-L73).

By default, fzf-tab will call the widget previously bound to "^I" to get the completion list. So there is no problem in most cases, unless fzf-tab is initialized before a plugin which doesn't handle the previous binding properly.

So if you find your fzf-tab doesn't work properly, please make sure it is the last plugin to bind "^I" (If you don't know what I mean, just put it to the end of your plugin list).

## Related projects

- https://github.com/lincheney/fzf-tab-completion (fzf tab completion for zsh, bash and GNU readline apps )
