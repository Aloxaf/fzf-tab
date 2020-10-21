#!/usr/bin/env zsh

local -a fzf_opts=($@)
fzf_opts=(${${fzf_opts/--height*}/--layout*})

# get position of cursor and size of window
local -a tmp=($(tmux display-message -p "#{pane_top} #{cursor_y} #{pane_left} #{cursor_x} #{window_height} #{window_width}"))
local cursor_y=$((tmp[1] + tmp[2])) cursor_x=$((tmp[3] + tmp[4])) window_height=$tmp[5] window_width=$tmp[6]

# create fifo and write to completion lists to file
mkfifo /tmp/fzf-tab-$$
cat > /tmp/fzf-tab-list-$$

# get the size of content, note we should remove all ANSI color code
local comp_lines=${#${(f)"$(</tmp/fzf-tab-list-$$)"}}
local comp_length=$(sed 's/\x1b\[[0-9;]*m//g' /tmp/fzf-tab-list-$$ | awk 'length > max_length { max_length = length; } END { print max_length }')

# calculate the popup height and y position
if (( comp_lines + 4 > window_height - cursor_y )); then
  local popup_y=$cursor_y
else
  local popup_y=$(( cursor_y + comp_lines + 5 ))
  fzf_opts+=(--layout=reverse)
fi
local max_popup_height=$(( 20 * 100 / window_height + 3 ))
if (( comp_lines >= window_height )); then
  local popup_height=$(( cursor_y * 100 / window_height + 3 ))
else
  local popup_height=$(( (comp_lines + 4) * 100 / window_height ))
fi
(( popup_height > max_popup_height )) && popup_height=$max_popup_height

# calculate the popup width and x position
local popup_x=$cursor_x
if (( comp_length >= window_width )); then
  local popup_width=$(( 100 - curosr_x * 100 / window_width ))
else
  local popup_width=$(( comp_length * 100 / window_width ))
fi
local popup_width=$(( 100 - curosr_x * 100 / window_width ))

# zenity --info --text="$comp_lines . $comp_length . $window_height . $window_width . $popup_height% . $popup_width% | $fzf_opts"
echo -E "fzf ${(qq)fzf_opts[@]} < /tmp/fzf-tab-list-$$ > /tmp/fzf-tab-$$"  > /tmp/fzf-tab-tmux.zsh
{
  tmux popup -x $popup_x -y $popup_y -w $popup_width% -h $popup_height% -KE -R "zsh /tmp/fzf-tab-tmux.zsh" &
  cat /tmp/fzf-tab-$$
} always {
  rm /tmp/fzf-tab-$$ /tmp/fzf-tab-list-$$
}
