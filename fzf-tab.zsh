zmodload zsh/zutil

# thanks Valodim/zsh-capture-completion
function compadd() {
    # parse all options
    local -A apre hpre ipre hsuf asuf isuf dscrs arg_O arg_A arg_D
    local isfile _opts
    zparseopts -E -a _opts P:=apre p:=hpre i:=ipre S:=asuf s:=hsuf I:=isuf d:=dscrs \
        O:=arg_O A:=arg_A D:=arg_D f=isfile J: V: X: x: r: R: W: F: M: E: \
        a k l o 1 2 q e Q n U C

    # just delegate and leave if any of -O, -A or -D are given or fzf-tab is not enabled
    if (( $#arg_O || $#arg_A || $#arg_D || ! IN_FZF_TAB )) {
        builtin compadd "$@"
        return
    }

    # store matches in $__hits and descriptions in $__dscr
    local -a __hits __dscr
    if (( $#dscrs == 1 )) {
        __dscr=( "${(@P)${(v)dscrs}}" )
    }
    builtin compadd -A __hits -D __dscr "$@"
    if (( $#__hits == 0 )) {
        return
    }

    # store these values in compcap
    local -a keys=(ipre apre hpre hsuf asuf isuf PREFIX SUFFIX isfile)
    local expanded __tmp_value="<"$'\0'">" # ensure that compcap's key will always exists
    # NOTE: I don't know why, but if I use `for i ($keys)` here I will get a coredump
    for i ({1..$#keys}) {
        expanded=${(P)keys[i]}
        if [[ -n $expanded ]] {
            __tmp_value+=$'\0'$keys[i]$'\0'$expanded
        }
    }

    # dscr - the string to show to users
    # word - the string to be inserted
    local dscr word
    for i ({1..$#__hits}) {
        word=$__hits[i] && dscr=$__dscr[i]
        if [[ -n $dscr ]] {
            dscr=${dscr//$'\n'}
        } elif [[ -n $word ]] {
            dscr=$word
        } else {
            continue
        }
        compcap[$dscr]=$__tmp_value${word:+$'\0'"word"$'\0'$word}
    }
    # tell zsh that the match is successful, but try not to change the buffer
    builtin compadd -Q -U -S "$SUFFIX" -- "$PREFIX"
}

[[ ${FZF_TAB_COMMAND:='fzf'} ]]
[[ ${FZF_TAB_OPTS:='-1 --cycle --layout=reverse --tiebreak=begin --bind tab:down,ctrl-j:accept --height=50%'} ]]
(( $+FZF_TAB_QUERY )) || {
    FZF_TAB_QUERY=(prefix input first)
}

# select result, first line is query string
function _fzf_tab_select() {
    local query ret
    read -r query
    if [[ $1 == first ]] {
        read -r ret
    } else {
        ret=$($FZF_TAB_COMMAND ${(z)FZF_TAB_OPTS} ${query:+-q$query})
    }
    echo -E ${ret%%$'\0'*}
}

# find longest common prefix of $1 and $2
function _fzf_tab_common_prefix() {
    local str1=$1 str2=$2 i
    for (( i=1; i<$#1; i++ )) {
        if [[ $str1[i] != $str2[i] ]] {
            break
        }
    }
    echo -E $str1[1,i-1]
}

# find valid query string
function _fzf_tab_find_query_str() {
    local -a keys=(${(k)compcap})
    local key qtype query tmp
    for qtype ($FZF_TAB_QUERY) {
        if [[ $qtype == prefix ]] {
            tmp=$keys[1]
            for key ($keys) {
                # _fzf_tab_common_prefix is slow, don't call it if they already have common prefix
                (( ${key[(i)$tmp]} != 1 )) && tmp=$(_fzf_tab_common_prefix $tmp $key)
            }
        } elif [[ $qtype == input ]] {
            local fv=${${(v)compcap}[1]}
            local -A v=(${(@0)fv})
            tmp=$v[PREFIX]
            if (( $RBUFFER[(i)$v[SUFFIX]] != 1 )) {
                tmp=${tmp/%$v[SUFFIX]}
            }
            tmp=${${tmp#$v[hpre]}#$v[apre]}
        }
        if (( $FZF_TAB_QUERY[(I)longest] )) {
            (( $#tmp > $#query )) && query=$tmp
        } elif [[ -n $tmp ]] {
            query=$tmp && break
        }
    }
    echo -E $query
}

# print query string(first line) and matches
function _fzf_tab_print_matches() {
    # print query string on the first line
    _fzf_tab_find_query_str

    local dsuf k _v filepath
    for k _v (${(kv)compcap}) {
        local -A v=("${(@0)_v}")
        # add a character to describe the type of the files
        # TODO: can be color?
        dsuf=
        if [[ -n $v[isfile] ]] {
            filepath=${(Q)~${v[hpre]}}${(Q)k}
            if [[ -L $filepath ]] {
                dsuf=@
            } elif [[ -d $filepath ]] {
                dsuf=/
            }
        }
        echo -E $k$'\0'$dsuf
    }
}

# TODO: can I use `compadd` to apply my choice?
function fzf-tab-complete() {
    local -A compcap
    local choice query b_BUFFER b_CURSOR

    b_BUFFER=$BUFFER && b_CURSOR=$CURSOR
    IN_FZF_TAB=1
    zle ${fzf_tab_default_completion:-expand-or-complete}
    IN_FZF_TAB=0

    if (( $#compcap == 0 )) {
        return
    }

    # expand-or-complete may change BUFFER
    # recover it before start our complete
    BUFFER=$b_BUFFER && CURSOR=$b_CURSOR
    zle redisplay
    if (( $#compcap == 1 )) {
        choice=$(_fzf_tab_print_matches | _fzf_tab_select first)
    } else {
        choice=$(_fzf_tab_print_matches | { read -r query; echo -E $query; sort -n } | _fzf_tab_select)
    }

    # for reference: Src/Zle/compresult.c:do_single:1129
    if [[ -n $choice ]] {
        local -A v=("${(@0)${compcap[$choice]}}")
        # if RBUFFER doesn't starts with SUFFIX, the completion position is at LBUFFER
        if (( $RBUFFER[(i)$v[SUFFIX]] != 1 )) {
            LBUFFER=${LBUFFER/%$v[SUFFIX]}
        } else {
            RBUFFER=${RBUFFER/#$v[SUFFIX]}
        }
        # don't add slash if have hsuf, so that /u/l/b can be expanded to /usr/lib/b not /usr/lib//b
        if [[ -z $v[hsuf] && -z $v[asuf] && -d ${(Q)~${v[hpre]}}${(Q)choice} ]] {
            v[word]+=/
        }
        # a temporarily fix for issue #6
        # there should be a better solution
        if [[ -n ${(M)LBUFFER%$v[PREFIX]} ]] {
            LBUFFER=${LBUFFER/%$v[PREFIX]}$v[ipre]$v[apre]$v[hpre]$v[word]$v[hsuf]$v[asuf]$v[isuf]
        } else {
            local to_insert=$v[ipre]$v[apre]$v[hpre]$v[word]$v[hsuf]$v[asuf]$v[isuf]
            LBUFFER=$LBUFFER${to_insert/#$v[PREFIX]}
        }
    }
    zle redisplay
}

zle -N fzf-tab-complete

function disable-fzf-tab() {
    bindkey '^I' expand-or-complete
}

function enable-fzf-tab() {
    local binding=$(bindkey '^I')
    if [[ ! $binding =~ "undefined-key" && $binding != fzf-tab-complete ]] {
        fzf_tab_default_completion=$binding[(w)2]
    }
    bindkey '^I' fzf-tab-complete
}

enable-fzf-tab
