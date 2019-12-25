# fzf-tab

Replace zsh's default completion selection menu with fzf!

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

Just press <TAB> as usual~

Some variables

- `FUZZY_COMPLETE_COMMAND`: Fuzzy search program 
- `FUZZY_COMPLETE_OPTIONS`: Its arguments

You can use `disable-fuzzy-complete` to disable `fzf-tab` if you come across any problem
and enable it with `enable-fuzzy-complete`.
