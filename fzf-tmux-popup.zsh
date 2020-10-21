#!/usr/bin/env zsh

local -a fzf_opts=($@)
fzf_opts=(${${fzf_opts/--height*}/--layout*})

# get position of cursor and size of window
local -a tmp=($(tmux display-message -p "#{pane_top} #{cursor_y} #{pane_left} #{cursor_x} #{window_height} #{window_width}"))
local cursor_y=$((tmp[1] + tmp[2])) cursor_x=$((tmp[3] + tmp[4])) window_height=$tmp[5] window_width=$tmp[6]

# create fifo and write to completion lists to file
touch /tmp/fzf-tab-$$
cat > /tmp/fzf-tab-list-$$

# get the size of content, note we should remove all ANSI color code
local comp_lines=${#${(f)"$(</tmp/fzf-tab-list-$$)"}}
local comp_length=$(sed 's/\x1b\[[0-9;]*m//g' /tmp/fzf-tab-list-$$ | awk 'length > max_length { max_length = length; } END { print max_length }')

# calculate the popup height and y position
if (( cursor_y * 2 > window_height )); then
  # show above the cursor
  local popup_height=$(( comp_lines >= cursor_y ? cursor_y : comp_lines + 4 ))
  local popup_y=$cursor_y
else
  # show below the cursor
  local popup_height=$(( comp_lines >= (window_height - cursor_y) ? window_height - cursor_y : comp_lines + 4 ))
  local popup_y=$(( cursor_y + popup_height + 1 ))
  fzf_opts+=(--layout=reverse)
fi

# calculate the popup width and x position
local popup_width=$(( comp_length + 4 > window_width ? window_width : comp_length + 4 ))
local popup_x=$(( cursor_x + popup_width > window_width ? window_width - popup_width : cursor_x ))

echo -E "fzf ${(qq)fzf_opts[@]} < /tmp/fzf-tab-list-$$ > /tmp/fzf-tab-$$"  > /tmp/fzf-tab-tmux.zsh
{
  tmux popup -x $popup_x -y $popup_y \
       -w $popup_width -h $popup_height \
       -KE -R "zsh /tmp/fzf-tab-tmux.zsh"
  cat /tmp/fzf-tab-$$
} always {
  rm /tmp/fzf-tab-$$ /tmp/fzf-tab-list-$$
}
