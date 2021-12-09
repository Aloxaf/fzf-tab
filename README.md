# fzf-tab

[![CI](https://github.com/Aloxaf/fzf-tab/workflows/ci/badge.svg)](https://github.com/Aloxaf/fzf-tab/actions?query=workflow%3Aci)
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
    - [Prezto](#prezto)
- [Usage](#usage)
    - [Configure](#configure)
    - [Binary module](#binary-module)
- [Difference from other plugins](#difference-from-other-plugins)
- [Compatibility with other plugins](#compatibility-with-other-plugins)
- [Related projects](#related-projects)

<!-- markdown-toc end -->

# Install

**NOTE: fzf-tab needs to be loaded after `compinit`, but before plugins which will wrap widgets, such as [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) or [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting)!!**

### Manual

First, clone this repository.

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~/somewhere
```

Then add the following line to your `~/.zshrc`.

```zsh
source ~/somewhere/fzf-tab.plugin.zsh
```

### Antigen

```zsh
antigen bundle Aloxaf/fzf-tab
```

### Zinit

```zsh
zinit light Aloxaf/fzf-tab
```

### Oh-My-Zsh

Clone this repository to your custom directory and then add `fzf-tab` to your plugin list.

```zsh
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
```

### Prezto

Clone this repository to your contrib directory and then add `fzf-tab` to your module list in `.zpreztorc`.

```zsh
git clone https://github.com/Aloxaf/fzf-tab $ZPREZTODIR/contrib/fzf-tab
```

# Usage

Just press <kbd>Tab</kbd> as usual~

Available keybindings:

- <kbd>Ctrl</kdb>+<kdb>Space</kbd>: select multiple results, can be configured by `fzf-bindings` tag

- <kbd>F1</kbd>/<kbd>F2</kbd>: switch between groups, can be configured by `switch-group` tag

- <kbd>/</kbd>: trigger continuous completion (useful when completing a deep path), can be configured by `continuous-trigger` tag

Available commands:

- `disable-fzf-tab`: disable fzf-tab and fallback to compsys

- `enable-fzf-tab`: enable fzf-tab

- `toggle-fzf-tab`: toggle the state of fzf-tab. This is also a zle widget.

## Configure

A common configuration is:

```zsh
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'
```

For more information, please see [Wiki#Configuration](https://github.com/Aloxaf/fzf-tab/wiki/Configuration).

## Binary module

By default, fzf-tab uses [zsh-ls-colors](https://github.com/xPMo/zsh-ls-colors) to parse and apply ZLS_COLORS if you have set the `list-colors` tag.

However, it is a pure zsh script and is slow if you have too many files to colorize.
fzf-tab is shipped with a binary module to speed up this process. You can build it with `build-fzf-tab-module`, then it will be enabled automatically.

# Difference from other plugins

fzf-tab doesn't do "complete", it just shows you the results of the default completion system.

So it works EVERYWHERE (variables, function names, directory stack, in-word completion, etc.).
And most of your configuration for default completion system is still valid.

# Compatibility with other plugins

Some plugins may also bind "^I" to their custom widget, like [fzf/shell/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh) or [ohmyzsh/lib/completion.zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh#L61-L73).

By default, fzf-tab will call the widget previously bound to "^I" to get the completion list. So there is no problem in most cases, unless fzf-tab is initialized before a plugin which doesn't handle the previous binding properly.

So if you find your fzf-tab doesn't work properly, **please make sure it is the last plugin to bind "^I"** (If you don't know what I mean, just put it to the end of your plugin list).

# Related projects

- https://github.com/lincheney/fzf-tab-completion (fzf tab completion for zsh, bash and GNU readline apps)
