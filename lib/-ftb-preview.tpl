zmodload zsh/mapfile
local -a _ftb_compcap=("${(@f)mapfile[__FTB_COMPCAP__]}")
local -a _ftb_groups=("${(@f)mapfile[__FTB_GROUPS__]}")
local bs=$'\2'

# get description
export desc=${${"$(<'{f}')"%$'\0'*}#*$'\0'}
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

