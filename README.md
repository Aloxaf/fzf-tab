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

- `FZF_TAB_COMMAND`: Fuzzy search program 
- `FZF_TAB_OPTS`: Its parameters

Some commands:

- `disable-fzf-tab`: Use it when you come across some bugs
- `enable-fzf-tab`: Use it when fzf-tab doesn't initialize properly.
