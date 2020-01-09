# temporarily change options
'builtin' 'local' '-a' '_fzf_tab_opts'
[[ ! -o 'aliases'         ]] || _fzf_tab_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _fzf_tab_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _fzf_tab_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

zmodload zsh/zutil

# thanks Valodim/zsh-capture-completion
compadd() {
    emulate -L zsh
    # parse all options
    local -A apre hpre dscrs _oad expl
    local -a isfile _opts __
    zparseopts -E -a _opts P:=apre p:=hpre d:=dscrs X:=expl O:=_oad A:=_oad D:=_oad f=isfile \
               i: S: s: I: x: r: R: W: F: M+: E: q e Q n U C \
               J:=__ V:=__ a=__ l=__ k=__ o=__ 1=__ 2=__

    # just delegate and leave if any of -O, -A or -D are given or fzf-tab is not enabled
    if (( $#_oad != 0 || ! IN_FZF_TAB )); then
        builtin compadd "$@"
        return
    fi

    # store matches in $__hits and descriptions in $__dscr
    local -a __hits __dscr
    if (( $#dscrs == 1 )); then
        __dscr=( "${(@P)${(v)dscrs}}" )
    fi
    builtin compadd -A __hits -D __dscr "$@"
    if (( $#__hits == 0 )); then
        return
    fi

    # keep order of group description
    _fzf_tab_groups+=$expl

    # store these values in _fzf_tab_compcap
    local -a keys=(apre hpre isfile PREFIX SUFFIX IPREFIX ISUFFIX)
    local key expanded __tmp_value="<"$'\0'">" # ensure that _fzf_tab_compcap's key will always exists
    for key in $keys; do
        expanded=${(P)key}
        if [[ $expanded ]]; then
            __tmp_value+=$'\0'$key$'\0'$expanded
        fi
    done
    if [[ $expl ]]; then
        __tmp_value+=$'\0group\0'$_fzf_tab_groups[(ie)$expl]
    fi
    _opts+=("${(@kv)apre}" "${(@kv)hpre}" $isfile)

    # dscr - the string to show to users
    # word - the string to be inserted
    local dscr word i
    for i in {1..$#__hits}; do
        word=$__hits[i] && dscr=$__dscr[i]
        if [[ -n $dscr ]]; then
            dscr=${dscr//$'\n'}
        elif [[ -n $word ]]; then
            dscr=$word
        else
            continue
        fi
        _fzf_tab_compcap[$dscr]=$__tmp_value${word:+$'\0'"word"$'\0'$word}$'\0'"args"$'\0'${(pj:\1:)_opts}
    done
    # tell zsh that the match is successful
    builtin compadd -Q -U ''
}

: ${FZF_TAB_MERGE_HEADERS:='1'}
: ${FZF_TAB_INSERT_SPACE:='1'}
: ${FZF_TAB_COMMAND:='fzf'}
: ${FZF_TAB_OPTS='--ansi --cycle --layout=reverse --color=hl:255 --tiebreak=begin --bind tab:down,ctrl-j:accept,change:top --height=90%'}
: ${(A)=FZF_TAB_GROUP_COLOR=$'\033[36m' $'\033[33m' $'\033[35m' $'\033[34m' $'\033[31m' $'\033[32m' \
       $'\033[93m' $'\033[38;5;21m' $'\033[38;5;28m' $'\033[38;5;094m' $'\033[38;5;144m' $'\033[38;5;210m' }
: ${(A)=FZF_TAB_QUERY=prefix input first}

# sets `query` to the valid query string
_fzf_tab_find_query_str() {
    local key qtype tmp
    typeset -g query=
    for qtype in $FZF_TAB_QUERY; do
        if [[ $qtype == prefix ]]; then
            # find the longest common prefix among ${(k)_fzf_tab_compcap}
            local -a keys=(${(k)_fzf_tab_compcap})
            tmp=$keys[1]
            local MATCH match mbegin mend prefix=(${(s::)tmp})
            for key in ${keys:1}; do
                (( $#tmp )) || break
                [[ $key == $tmp* ]] && continue
                # interpose characters from the current common prefix and $key and see how
                # many pairs of equal characters we get at the start of the resulting string
                [[ ${(j::)${${(s::)key[1,$#tmp]}:^prefix}} =~ '^(((.)\3)*)' ]]
                # truncate common prefix and maintain loop invariant: ${(s::)tmp} == $prefix
                tmp[$#MATCH/2+1,-1]=""
                prefix[$#MATCH/2+1,-1]=()
            done
        elif [[ $qtype == input ]]; then
            local fv=${${(v)_fzf_tab_compcap}[1]}
            local -A v=("${(@0)fv}")
            tmp=$v[PREFIX]
            if (( $RBUFFER[(i)$v[SUFFIX]] != 1 )); then
                tmp=${tmp/%$v[SUFFIX]}
            fi
            tmp=${${tmp#$v[hpre]}#$v[apre]}
        fi
        if (( $FZF_TAB_QUERY[(I)longest] )); then
            (( $#tmp > $#query )) && query=$tmp
        elif [[ -n $tmp ]]; then
            query=$tmp && break
        fi
    done
}

# pupulates array `headers` with group descriptions
_fzf_tab_get_headers() {
    typeset -ga headers=()
    local MATCH match mbegin mend tmp=()
    local -i len=0 tabsize=8
    # we need the value of tabsize to calculate the actual width
    [[ $FZF_TAB_OPTS =~ '.*--tabstop[= ]([0-9]+).*' ]] && tabsize=$match
    for k in {1..$#_fzf_tab_groups}; do
        if (( len + $#_fzf_tab_groups[k] > COLUMNS - 5)) \
               || (( $#tmp && ! FZF_TAB_MERGE_HEADERS )); then
            headers+=${(pj:\t:)tmp}
            len=0
            tmp=()
        fi
        tmp+=$FZF_TAB_GROUP_COLOR[k]$_fzf_tab_groups[k]$'\033[00m'
        len+=$#_fzf_tab_groups[k]
        (( len % tabsize != 0 )) && (( len += tabsize - len % tabsize ))
    done
    (( $#tmp )) && headers+=${(pj:\t:)tmp}
}

# pupulates array `candidates` with completion candidates
_fzf_tab_get_candidates() {
    local dsuf k _v filepath first_word
    local -i same_word=1
    typeset -ga candidates=()
    for k _v in ${(kv)_fzf_tab_compcap}; do
        local -A v=("${(@0)_v}")
        [[ $v[word] == ${first_word:=$v[word]} ]] || same_word=0
        # add a character to describe the type of the files
        # TODO: can be color?
        dsuf=
        if [[ -n $v[isfile] ]]; then
            filepath=${(Q)~${v[hpre]}}${(Q)k}
            if [[ -L $filepath ]]; then
                dsuf=@
            elif [[ -d $filepath ]]; then
                dsuf=/
            fi
        fi

        # add color to description if they have group description
        if [[ $v[group] ]]; then
            local color=$FZF_TAB_GROUP_COLOR[$v[group]]
            # add a hidden group index at start of string to keep group order when sorting
            # FIXME: only support 16 groups
            candidates+=$(( [##16] $v[group] ))$'\b'$color$'\0'$k$'\0'$dsuf$'\033[00m'
        else
            candidates+=1$'\b\0'$k$'\0'$dsuf
        fi
    done
    (( same_word )) && candidates[2,-1]=()
    local LC_ALL=C
    candidates=("${(@on)candidates}")
}

_fzf_tab_complete() {
    local -A _fzf_tab_compcap
    local -Ua _fzf_tab_groups
    local choice

    IN_FZF_TAB=1
    _main_complete  # must run with user options; don't move `emulate -L zsh` above this line
    IN_FZF_TAB=0

    emulate -L zsh

    local query candidates=() headers=()
    _fzf_tab_get_candidates  # sets `candidates`

    case $#candidates in
        0) return;;
        1) choice=${${(k)_fzf_tab_compcap}[1]};;
        *)
            _fzf_tab_find_query_str  # sets `query`
            _fzf_tab_get_headers     # sets `headers`
            if (( $#headers )); then
                choice=$($FZF_TAB_COMMAND \
                             ${(z)FZF_TAB_OPTS} ${query:+-q$query} --header-lines=$#headers \
                             <<<${(pj:\n:)headers} <<<${(pj:\n:)candidates})
            else
                choice=$($FZF_TAB_COMMAND \
                             ${(z)FZF_TAB_OPTS} ${query:+-q$query} <<<${(pj:\n:)candidates})
            fi
            choice=${${choice%$'\0'*}#*$'\0'}
            ;;
    esac

    compstate[insert]=
    compstate[list]=
    if [[ -n $choice ]]; then
        local -A v=("${(@0)${_fzf_tab_compcap[$choice]}}")
        local -a args=("${(@ps:\1:)v[args]}")
        [[ -z $args[1] ]] && args=()  # don't pass an empty string
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX] \
               builtin compadd "${args[@]:--Q}" -Q -- $v[word]
        # the first result is '' (see the last line of compadd)
        compstate[insert]='2'
        (( ! FZF_TAB_INSERT_SPACE )) || [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
    fi
}

zle -C _fzf_tab_complete complete-word _fzf_tab_complete

fzf-tab-complete() {
    zle _fzf_tab_complete  # must run with user options; don't add `emulate -L zsh` above this line
    zle redisplay
}

zle -N fzf-tab-complete

disable-fzf-tab() {
    emulate -L zsh
    if (( $+_fzf_tab_orig_widget )); then
        bindkey '^I' $_fzf_tab_orig_widget
        unset _fzf_tab_orig_widget
    fi
    case $_fzf_tab_orig_list_grouped in
        0) zstyle ':completion:*' list-grouped false ;;
        1) zstyle ':completion:*' list-grouped true ;;
        2) zstyle -d ':completion:*' list-grouped ;;
    esac
    unset _fzf_tab_orig_list_groupded
}

enable-fzf-tab() {
    emulate -L zsh
    typeset -g _fzf_tab_orig_widget="${$(bindkey '^I')##* }"
    zstyle -t ':completion:*' list-grouped false
    typeset -g _fzf_tab_orig_list_grouped=$?

    zstyle ':completion:*' list-grouped false
    bindkey '^I' fzf-tab-complete
}

enable-fzf-tab

# restore options
(( ${#_fzf_tab_opts} )) && setopt ${_fzf_tab_opts[@]}
'builtin' 'unset' '_fzf_tab_opts'
