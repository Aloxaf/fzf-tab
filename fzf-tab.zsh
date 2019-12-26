# no group and list separator
zstyle ':completion:*' list-grouped false
zstyle ':completion:*' list-separator ''

zmodload zsh/zutil

# thanks Valodim/zsh-capture-completion
function compadd() {
    # parse all options
    typeset -A apre hpre ipre hsuf asuf isuf arg_d arg_J arg_V \
         arg_X arg_x arg_r arg_R arg_W arg_F arg_M arg_O arg_A arg_D arg_E
    local flag_a flag_k flag_l flag_o flag_1 flag_2 flag_q isfile \
         flag_e flag_Q flag_n flag_U flag_C
    zparseopts -E P:=apre p:=hpre i:=ipre S:=asuf s:=hsuf I:=isuf d:=arg_d \
        J:=arg_J V:=arg_V X:=arg_X x:=arg_x r:=arg_r R:=arg_R W:=arg_W F:=arg_F \
        M:=arg_M O:=arg_O A:=arg_A D:=arg_D E:=arg_E \
        a=flag_a k=flag_k l=flag_l o=flag_o 1=flag_1 2=flag_2 q=flag_q \
        f=isfile e=flag_e Q=flag_Q n=flag_n U=flag_U C=flag_C

    # just delegate and leave if any of -O, -A or -D are given or fzf-tab is not enabled
    if (( $#arg_O || $#arg_A || $#arg_D || ! IN_FZF_TAB )) {
        builtin compadd "$@"
        return $?
    }

    # store matches in $__hits and descriptions in $__dscr
    typeset -a __hits __dscr
    if (( $#arg_d == 1 )) {
        __dscr=( "${(@P)${(v)arg_d}}" )
    }
    builtin compadd -A __hits -D __dscr "$@"
    if (( $#__hits == 0 )) {
        return
    }

    # store these values in compcap_list
    local -a keys=(ipre apre hpre hsuf asuf isuf PREFIX SUFFIX isfile)
    local __tmp_value="<"$'\0'">" expanded  # 
    # NOTE: I don't know why, but if I use `for i ($keys)` here I will get a coredump
    for i ({1..$#keys}) {
        expanded=${(P)keys[$i]}
        if [[ -n $expanded ]] {
            __tmp_value+=$'\0'$keys[$i]$'\0'$expanded
        }
    }

    # add the matches and descriptions
    setopt localoptions extendedglob
    local dscr
    for i ({1..$#__hits}) {
        # description
        dscr=
        if (( $#__dscr >= $i )) {
            dscr="${${${__dscr[$i]}##$__hits[$i] #}//$'\n'}"
        }
        compcap_list[$__hits[$i]]=$__tmp_value${dscr:+$'\0'"dscr"$'\0'$dscr}
    }
}

[[ ${FUZZY_COMPLETE_COMMAND:='fzf'} ]]
[[ ${FUZZY_COMPLETE_OPTIONS:='-1 --ansi --cycle --layout=reverse --tiebreak=begin --bind tab:down,ctrl-j:accept --height=50%'} ]]

function _fuzzy_select() {
    local query ret
    read -r query
    if [[ $1 == first ]] {
        read -r ret
    } else {
        ret=$($FUZZY_COMPLETE_COMMAND ${(z)FUZZY_COMPLETE_OPTIONS} ${query:+-q $query})
    }
    echo ${ret%%$'\0'*}
}

function _find_common_prefix() {
    local str1=$1 str2=$2
    for (( i=1; i<$#1; i++ )) {
        if [[ $str1[i] != $str2[i] ]] {
            break
        }
    }
    echo $str1[1,i-1]
}

function _compcap_pretty_print() {
    local -i max_length=0
    local -a keys=(${(k)compcap_list}) values=(${(v)compcap_list})

    # find max length and common prefix of command
    local common_prefix=$keys[1]
    for i ($keys) {
        (( $#i > max_length )) && max_length=$#i
        # _find_common_prefix is slow, don't call it if they already have common prefix
        (( ${i[(i)$common_prefix]} != 1 )) && common_prefix=$(_find_common_prefix $common_prefix $i)
    }
    echo $common_prefix
    max_length+=3

    # NOTE: If I use ${(kv)compcap_list} here, wd's completion will get error,
    # the order of k and v will be exchanged, and I don't know why
    local dsuf
    for k v (${keys:^values}) {
        local -A v=("${(@0)v}")
        # add a character to describe the type of the files
        # TODO: can be color?
        dsuf=
        if [[ -n $v[isfile] ]] {
            # FIXME: a directory with '*|['... in its name can not be detected
            if [[ -L ${~${v[hpre]}}$k ]] {
                dsuf=@
            } elif [[ -d ${~${v[hpre]}}$k ]] {
                dsuf=/
            }
        }
        if [[ -z $v[dscr] ]] {
            echo -E $k$'\0'$dsuf
        } else {
            printf "%-${max_length}s${v[dscr]}\n" $k$'\0'
        }
    }
}

# TODO: can I use `compadd` to apply my choice?
function fuzzy-complete() {
    local -A compcap_list
    local selected

    IN_FZF_TAB=1
    zle expand-or-complete
    IN_FZF_TAB=0

    if (( $#compcap_list == 0 )) {
        return
    } elif (( $#compcap_list == 1 )) {
        selected=$(_compcap_pretty_print | _fuzzy_select first)
    } else {
        selected=$(_compcap_pretty_print | sort | _fuzzy_select)
    }

    if [[ -n $selected ]] {
        local -A v=("${(@0)${compcap_list[$selected]}}")
        # if RBUFFER doesn't starts with SUFFIX, the completion position is at LBUFFER
        if (( $RBUFFER[(i)$v[SUFFIX]] != 1 )) {
            LBUFFER=${LBUFFER/%$v[SUFFIX]}
        } else {
            RBUFFER=${RBUFFER/#$v[SUFFIX]}
        }
        # don't add slash if have hsuf, so that /u/l/b can be expanded to /usr/lib/b not /usr/lib//b
        if [[ -z $v[hsuf] && -d ${~${v[hpre]}}$selected ]] {
            selected+=/
        }
        LBUFFER=${LBUFFER/%$v[PREFIX]}$v[ipre]$v[apre]$v[hpre]$selected$v[hsuf]$v[asuf]$v[isuf]
    }
    zle reset-prompt
}

zle -N fuzzy-complete

function disable-fuzzy-complete() {
    bindkey '^I' expand-or-complete
}

function enable-fuzzy-complete() {
    bindkey '^I' fuzzy-complete
}

enable-fuzzy-complete
