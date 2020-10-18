#!/usr/bin/env zsh

mkfifo /tmp/fzf-tab-$$

cat > /tmp/fzf-tab-list-$$

tmux popup -w80% -h50% -KE -R "fzf $1 < /tmp/fzf-tab-list-$$ > /tmp/fzf-tab-$$" &

cat /tmp/fzf-tab-$$

