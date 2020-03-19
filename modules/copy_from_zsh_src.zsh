#!/usr/bin/env zsh

[[ -z "$1" || "$1" = "-h" || "$1" = "--help" ]] && { print "Single argument: path to Zsh source tree"; exit 0; }

print "Will invoke git clean -dxf, 3 seconds"
sleep 3

git clean -dxf

[[ ! -d "$1" ]] && { print "Path to Zsh source doesn't exist (i.e.: $1)"; exit 1; }

local from="$1"

autoload -Uz colors
colors

integer count=0

for i in configure.ac Src/*.c Src/*.h; do
    if [[ -f "$from/$i" ]]; then
        cp -vf "$from/$i" "$i" && (( ++ count )) || print "${fg_bold[red]}Copy error for: $i${reset_color}"
    else
        print "${fg[red]}$i Doesn't exist${reset_color}"
    fi
done

echo "${fg[green]}Copied ${fg[yellow]}$count${fg[green]} files${reset_color}"

patch -p2 -i ./patch_cfgac.diff
