zmodload zsh/mapfile
local -a _ftb_compcap=("${(@f)mapfile[__FTB_COMPCAP__]}")
local -a _ftb_groups=("${(@f)mapfile[__FTB_GROUPS__]}")
local bs=$'\2'

# get description
# NOTE: keep {f} unquoted here so -ftb-fzf can rewrite it to $1 for {_FTB_INIT_}.
# Quoting it (e.g. '{f}') would turn rewritten '$1' into a literal string.
local _ftb_cur_file={f}
export desc=${${"$(<$_ftb_cur_file)"%$'\0'*}#*$'\0'}
# get ctxt for current completion
local -A ctxt=("${(@0)${_ftb_compcap[(r)${(b)desc}$bs*]#*$bs}}")
# get group
if (( $+ctxt[group] )); then
  export group=$_ftb_groups[$ctxt[group]]
fi
# get original word
export word=${(Q)ctxt[word]}
# get real path if it is file
if (( $+ctxt[realdir] )); then
  export realpath=${ctxt[realdir]}$word
fi
__FTB_WORDS_DUMP__

