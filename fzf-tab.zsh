# temporarily change options
'builtin' 'local' '-a' '_fzf_tab_opts'
[[ ! -o 'aliases'         ]] || _fzf_tab_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _fzf_tab_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _fzf_tab_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

zmodload zsh/zutil

# thanks Valodim/zsh-capture-completion
compadd() {
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
    [[ -n $expl ]] && _fzf_tab_groups+=$expl

    # store these values in _fzf_tab_compcap
    local -a keys=(apre hpre isfile PREFIX SUFFIX IPREFIX ISUFFIX)
    local key expanded __tmp_value=$'<\0>' # placeholder
    for key in $keys; do
        expanded=${(P)key}
        if [[ $expanded ]]; then
            __tmp_value+=$'\0'$key$'\0'$expanded
        fi
    done
    if [[ $expl ]]; then
        # store group index
        __tmp_value+=$'\0group\0'$_fzf_tab_groups[(ie)$expl]
    fi
    _opts+=("${(@kv)apre}" "${(@kv)hpre}" $isfile)
    __tmp_value+=$'\0args\0'${(pj:\1:)_opts}

    # dscr - the string to show to users
    # word - the string to be inserted
    local dscr word i cnt=$#_fzf_tab_compcap
    for i in {1..$#__hits}; do
        word=$__hits[i] && dscr=$__dscr[i]
        if [[ -n $dscr ]]; then
            dscr=${dscr//$'\n'}
        elif [[ -n $word ]]; then
            dscr=$word
        else
            continue
        fi
        if [[ $FZF_TAB_SORT != "1" ]]; then
            dscr=$((i + cnt))$'\b'$dscr
        fi
        _fzf_tab_compcap[$dscr]=$__tmp_value${word:+$'\0word\0'$word}
    done
    # tell zsh that the match is successful
    case $FZF_TAB_FAKE_COMPADD in
        fakeadd) nm=-1 ;;  # see _alternative:76
        *) builtin compadd -U -qS '' -R _fzf_tab_remove_space '' ;;
    esac
}

# when insert multi results, a whitespace will be added to each result
# remove left space of our fake result because I can't remove right space
# FIXME: what if the left char is not whitespace: `echo $widgets[\t`
_fzf_tab_remove_space() {
    [[ $LBUFFER[-1] == ' ' ]] && LBUFFER[-1]=''
}

: ${FZF_TAB_INSERT_SPACE:='1'}
: ${FZF_TAB_FAKE_COMPADD:='default'}
: ${FZF_TAB_COMMAND:='fzf'}
: ${FZF_TAB_SHOW_GROUP:=full}
: ${FZF_TAB_SORT:='1'}
: ${FZF_TAB_NO_GROUP_COLOR:=$'\033[37m'}
: ${FZF_TAB_CONTINUOUS_TRIGGER:='/'}
: ${(A)=FZF_TAB_QUERY=prefix input first}
: ${(A)=FZF_TAB_SINGLE_GROUP=color header}
: ${(A)=FZF_TAB_GROUP_COLORS=\
    $'\033[94m' $'\033[32m' $'\033[33m' $'\033[35m' $'\033[31m' $'\033[38;5;27m' $'\033[36m' \
    $'\033[38;5;100m' $'\033[38;5;98m' $'\033[91m' $'\033[38;5;80m' $'\033[92m' \
    $'\033[38;5;214m' $'\033[38;5;165m' $'\033[38;5;124m' $'\033[38;5;120m'
}

(( $+FZF_TAB_OPTS )) || FZF_TAB_OPTS=(
    --ansi   # Enable ANSI color support, necessary for showing groups
    --expect='$FZF_TAB_CONTINUOUS_TRIGGER' # For continuous completion 
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\x00'  # Don't search FZF_TAB_PREFIX
    --layout=reverse --height=75%
    --tiebreak=begin -m --bind=tab:down,ctrl-j:accept,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)

if zstyle -m ':completion:*:descriptions' format '*'; then
    : ${FZF_TAB_PREFIX='·'}
else
    : ${FZF_TAB_PREFIX=''}
fi

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
    local i tmp
    local -i mlen=0 len=0

    if (( $#_fzf_tab_groups == 1 && ! $FZF_TAB_SINGLE_GROUP[(I)header] )); then
        return
    fi

    # calculate the max column width
    for i in $_fzf_tab_groups; do
        (( $#i > mlen )) && mlen=$#i
    done
    mlen+=1

    for (( i=1; i<=$#_fzf_tab_groups; i++ )); do
        [[ $_fzf_tab_groups[i] == "__hide__"* ]] && continue

        if (( len + $#_fzf_tab_groups[i] > COLUMNS - 5 )); then
            headers+=$tmp
            tmp='' && len=0
        fi
        if (( len + mlen > COLUMNS - 5 )); then
            # the last column doesn't need padding
            headers+=$tmp$FZF_TAB_GROUP_COLORS[i]$_fzf_tab_groups[i]$'\033[00m'
            tmp='' && len=0
        else
            tmp+=$FZF_TAB_GROUP_COLORS[i]${(r:$mlen:)_fzf_tab_groups[i]}$'\033[00m'
            len+=$mlen
        fi
    done
    (( $#tmp )) && headers+=$tmp
}

# pupulates array `candidates` with completion candidates
_fzf_tab_get_candidates() {
    setopt localoptions extendedglob
    local dsuf k _v filepath first_word
    local -i same_word=1
    local -Ua duplicate_groups=()
    local -A word_map=()
    typeset -ga candidates=()

    if (( $#_fzf_tab_groups == 1 )); then
        (( $FZF_TAB_SINGLE_GROUP[(I)prefix] )) || local FZF_TAB_PREFIX=''
        (( $FZF_TAB_SINGLE_GROUP[(I)color] )) || local FZF_TAB_GROUP_COLORS=($FZF_TAB_NO_GROUP_COLOR)
    fi

    for k _v in ${(kv)_fzf_tab_compcap}; do
        local -A v=("${(@0)_v}")
        [[ $v[word] == ${first_word:=$v[word]} ]] || same_word=0
        # add a character to describe the type of the files
        # TODO: can be color?
        dsuf=
        if (( $+v[isfile] )); then
            filepath=${(Q)~${v[hpre]}}${(Q)k}
            if [[ -L $filepath ]]; then
                dsuf=@
            elif [[ -d $filepath ]]; then
                dsuf=/
            fi
        fi

        # add color to description if they have group description
        if (( $+v[group] )); then
            local color=$FZF_TAB_GROUP_COLORS[$v[group]]
            # add a hidden group index at start of string to keep group order when sorting
            candidates+=$v[group]$'\b'$color$FZF_TAB_PREFIX$'\0'$k$'\0'$dsuf$'\033[00m'
        else
            candidates+=$FZF_TAB_SINGLE_COLOR$FZF_TAB_PREFIX$'\0'$k$'\0'$dsuf$'\033[00m'
        fi

        # check group with duplicate member
        if [[ $FZF_TAB_SHOW_GROUP == brief ]]; then
            if (( $+word_map[$v[word]] && $+v[group] )); then
                duplicate_groups+=$v[group]            # add this group
                duplicate_groups+=$word_map[$v[word]]  # add previous group
            fi
            word_map[$v[word]]=$v[group]
        fi
    done
    (( $#candidates == 0 )) && return

    (( same_word )) && candidates[2,-1]=()

    # sort and remove sort group or other index
    candidates=("${(@on)candidates}")
    candidates=(${(@)candidates//[0-9]#$'\b'})

    # hide needless group
    if [[ $FZF_TAB_SHOW_GROUP == brief ]]; then
        local i indexs=({1..$#_fzf_tab_groups})
        for i in ${indexs:|duplicate_groups}; do
            # NOTE: _fzf_tab_groups is unique array
            _fzf_tab_groups[i]="__hide__$i"
        done
    fi
}

_fzf_tab_complete() {
    local -A _fzf_tab_compcap
    local -Ua _fzf_tab_groups
    local choice choices

    IN_FZF_TAB=1
    _main_complete  # must run with user options; don't move `emulate -L zsh` above this line
    IN_FZF_TAB=0

    emulate -L zsh

    local query candidates=() headers=()
    _fzf_tab_get_candidates  # sets `candidates`

    case $#candidates in
        0) return;;
        1) choices=(${${(k)_fzf_tab_compcap}[1]});;
        *)
            _fzf_tab_find_query_str  # sets `query`
            _fzf_tab_get_headers     # sets `headers`

            [[ ${(t)FZF_TAB_OPTS} != *"array"* ]] && FZF_TAB_OPTS=(${(z)FZF_TAB_OPTS})
            local -a command=($FZF_TAB_COMMAND $FZF_TAB_OPTS)

            if (( $#headers )); then
                choices=$(${(eX)command} <<<${(pj:\n:)headers} <<<${(pj:\n:)candidates})
            else
                choices=$(${(eX)command} <<<${(pj:\n:)candidates})
            fi
            choices=(${${${(f)choices}%$'\0'*}#*$'\0'})
            ;;
    esac

    if [[ $choices[1] == $FZF_TAB_CONTINUOUS_TRIGGER ]]; then
        typeset -gi _fzf_tab_continue=1
        choices[1]=()
    fi

    for choice in $choices; do
        local -A v=("${(@0)${_fzf_tab_compcap[$choice]}}")
        local -a args=("${(@ps:\1:)v[args]}")
        [[ -z $args[1] ]] && args=()  # don't pass an empty string
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX] \
               builtin compadd "${args[@]:--Q}" -Q -- $v[word]
    done

    compstate[list]=
    compstate[insert]=
    if (( $#choices == 1 )); then
        if [[ $FZF_TAB_FAKE_COMPADD == "fakeadd" ]]; then
            compstate[insert]='1'
        else
            compstate[insert]='2'
        fi
        (( ! FZF_TAB_INSERT_SPACE )) || [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
    elif (( $#choice > 1 )); then
        compstate[insert]='all'
    fi
}

zle -C _fzf_tab_complete complete-word _fzf_tab_complete

fzf-tab-complete() {
    # complete or not complete, this is a question
    # this name must be ugly to avoid clashes
    local -i _fzf_tab_continue=1 _fzf_tab_should_complete=0
    while (( _fzf_tab_continue )); do
        _fzf_tab_should_complete=0
        _fzf_tab_continue=0
        if (( ${+functions[_main_complete]} )); then
            # hack: hook _main_complete to check whether completion function will be called
            local orig_main_complete=${functions[_main_complete]}
            function _main_complete() { typeset -g _fzf_tab_should_complete=1; }
            {
                zle $_fzf_tab_orig_widget
            } always {
                functions[_main_complete]=$orig_main_complete
            }
        fi
        # must run with user options; don't add `emulate -L zsh` above this line
        (( ! _fzf_tab_should_complete )) || zle _fzf_tab_complete
        zle redisplay
    done
}

zle -N fzf-tab-complete

disable-fzf-tab() {
    typeset -g _ZSH_FZF_TAB_DISABLED
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
    unset _ZSH_FZF_TAB_DISABLED
    emulate -L zsh
    typeset -g _fzf_tab_orig_widget="${$(bindkey '^I')##* }"
    zstyle -t ':completion:*' list-grouped false
    typeset -g _fzf_tab_orig_list_grouped=$?

    zstyle ':completion:*' list-grouped false
    bindkey '^I' fzf-tab-complete
}

toggle-fzf-tab() {
    if [[ -n "${_ZSH_FZF_TAB_DISABLED+x}" ]]; then
	    enable-fzf-tab
    else
	    disable-fzf-tab
    fi
}

toggle-sort-fzf-tab() {
    if [[ ${FZF_TAB_SORT} == 1 ]]; then
	    FZF_TAB_SORT=0
    else
	    FZF_TAB_SORT=1
    fi
}

enable-fzf-tab
zle -N toggle-fzf-tab
zle -N toggle-sort-fzf-tab

# restore options
(( ${#_fzf_tab_opts} )) && setopt ${_fzf_tab_opts[@]}
'builtin' 'unset' '_fzf_tab_opts'
