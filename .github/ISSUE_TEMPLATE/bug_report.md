---
name: Bug report
about: Create a report to help us improve
title: "[BUG]"
labels: bug
assignees: ''

---

#### Describe the bug
A clear and concise description of what the bug is.

I can make sure:
- [ ] I am using the latest version of fzf-tab
- [ ] this is the minimal zshrc which can reproduce this bug
- [ ] fzf-tab is loaded after `compinit`
- [ ] fzf-tab is loaded after plugins which will wrap <kbd>Tab</kbd>, like [junegunn/fzf/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh)
- [ ] fzf-tab is loaded before zsh-autosuggestions, zsh-syntax-highlighting and fast-syntax-highlighting.

#### To Reproduce
Steps to reproduce the behavior:
1. Type '...'
2. Press <kbd>Tab</kbd>
4. See error

#### Expected behavior
A clear and concise description of what you expected to happen.

#### Screenshots
If applicable, add screenshots to help explain your problem.

#### Environment:
 - OS: [e.g. Arch Linux]
 - zsh version: [e.g. 5.8.1]

#### Minimal zshrc
If applicable, add a minimal zshrc to help us analyze.

#### Log
If applicable, use `C-x .` to trigger completion and provide the log.

If there are only three lines in your log, please make sure your fzf-tab is loaded with the correct order (see the checklist above).
