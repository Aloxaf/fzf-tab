zmodload zsh/zutil

# thanks Valodim/zsh-capture-completion
function compadd() {
    # parse all options
    local -A apre hpre dscrs _oad
    local -a isfile _opts __
    zparseopts -E -a _opts P:=apre p:=hpre d:=dscrs O:=_oad A:=_oad D:=_oad f=isfile \
        i: S: s: I: X: x: r: R: W: F: M+: E: q e Q n U C \
        J:=__ V:=__ a=__ l=__ k=__ o=__ 1=__ 2=__

    # just delegate and leave if any of -O, -A or -D are given or fzf-tab is not enabled
    if (( $#_oad != 0 || ! IN_FZF_TAB )) {
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
    local -a keys=(apre hpre isfile PREFIX SUFFIX IPREFIX ISUFFIX)
    local expanded __tmp_value="<"$'\0'">" # ensure that compcap's key will always exists
    # NOTE: I don't know why, but if I use `for i ($keys)` here I will get a coredump
    for i ({1..$#keys}) {
        expanded=${(P)keys[i]}
        if [[ -n $expanded ]] {
            __tmp_value+=$'\0'$keys[i]$'\0'$expanded
        }
    }
    _opts+=("${(@kv)apre}" "${(@kv)hpre}" $isfile)

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
        compcap[$dscr]=$__tmp_value${word:+$'\0'"word"$'\0'$word}$'\0'"args"$'\0'${(pj:\1:)_opts}
    }
    # tell zsh that the match is successful
    builtin compadd -Q -U ''
}

: ${FZF_TAB_INSERT_SPACE:='1'}
: ${FZF_TAB_COMMAND:='fzf'}
: ${FZF_TAB_OPTS='--cycle --layout=reverse --tiebreak=begin --bind tab:down,ctrl-j:accept --height=15'}
: ${(A)=FZF_TAB_QUERY=prefix input first}

# sets `query` to the valid query string
function _fzf_tab_find_query_str() {
    local key qtype tmp
    typeset -g query=
    for qtype ($FZF_TAB_QUERY) {
        if [[ $qtype == prefix ]] {
            # find the longest common prefix among ${(k)compcap}
            local -a keys=(${(k)compcap})
            tmp=$keys[1]
            local MATCH match mbegin mend prefix=(${(s::)tmp})
            for key (${keys:1}) {
                (( $#tmp )) || break
                [[ $key == $tmp* ]] && continue
                # interpose characters from the current common prefix and $key and see how
                # many pairs of equal characters we get at the start of the resulting string
                [[ ${(j::)${${(s::)key[1,$#tmp]}:^prefix}} =~ '^(((.)\3)*)' ]]
                # truncate common prefix and maintain loop invariant: ${(s::)tmp} == $prefix
                tmp[$#MATCH/2+1,-1]=""
                prefix[$#MATCH/2+1,-1]=()
            }
        } elif [[ $qtype == input ]] {
            local fv=${${(v)compcap}[1]}
            local -A v=("${(@0)fv}")
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
}

# pupulates array `candidates` with completion candidates
function _fzf_tab_get_candidates() {
    local dsuf k _v filepath
    typeset -ga candidates=()
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
        candidates+=$k$'\0'$dsuf
    }
    local LC_ALL=C
    candidates=("${(@on)candidates}")
}

# TODO: can I use `compadd` to apply my choice?
function _fzf_tab_complete() {
    local -A compcap
    local choice

    IN_FZF_TAB=1
    _main_complete
    IN_FZF_TAB=0

    case $#compcap in
      0) return;;
      1) choice=${(k)compcap};;
      *)
        local query candidates=()
        _fzf_tab_find_query_str  # sets `query`
        _fzf_tab_get_candidates  # sets `candidates`
        choice=$($FZF_TAB_COMMAND ${(z)FZF_TAB_OPTS} ${query:+-q$query} <<<${(pj:\n:)candidates})
        choice=${choice%%$'\0'}
      ;;
    }

    compstate[insert]=
    compstate[list]=
    if [[ -n $choice ]] {
        local -A v=("${(@0)${compcap[$choice]}}")
        local -a args=("${(@ps:\1:)v[args]}")
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX] builtin compadd "${args[@]:-Q}" -Q -- $v[word]
        # the first result is '' (see the last line of compadd)
        compstate[insert]='2'
        (( ! FZF_TAB_INSERT_SPACE )) || [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
    }
}

zle -C _fzf_tab_complete complete-word _fzf_tab_complete

function fzf-tab-complete() {
    zle _fzf_tab_complete
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
