# temporarily change options
'builtin' 'local' '-a' '_fzf_tab_opts'
[[ ! -o 'aliases'         ]] || _fzf_tab_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _fzf_tab_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _fzf_tab_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

zmodload zsh/zutil
zmodload -F zsh/stat b:zstat

source ${0:h}/lib/zsh-ls-colors/ls-colors.zsh fzf-tab-lscolors

# thanks Valodim/zsh-capture-completion
_fzf_tab_compadd() {
    # parse all options
    local -A apre hpre dscrs _oad expl
    local -a isfile _opts __
    zparseopts -E -a _opts P:=apre p:=hpre d:=dscrs X:=expl O:=_oad A:=_oad D:=_oad f=isfile \
               i: S: s: I: x: r: R: W: F: M+: E: q e Q n U C \
               J:=__ V:=__ a=__ l=__ k=__ o=__ 1=__ 2=__

    # just delegate and leave if any of -O, -A or -D are given or fzf-tab is not enabled
    zstyle -t ":fzf-tab:${curcontext#:}" ignore
    if (( $#_oad != 0 || ! IN_FZF_TAB || ! $? )); then
        builtin compadd "$@"
        return
    fi

    # store matches in $__hits and descriptions in $__dscr
    local -a __hits __dscr
    if (( $#dscrs == 1 )); then
        __dscr=( "${(@P)${(v)dscrs}}" )
    fi
    builtin compadd -A __hits -D __dscr "$@"
    local ret=$?
    if (( $#__hits == 0 )); then
        return $ret
    fi

    # store $curcontext for furthur usage
    _fzf_tab_curcontext=${curcontext#:}

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
    local dscr word i
    for i in {1..$#__hits}; do
        word=$__hits[i] dscr=$__dscr[i]
        if [[ -n $dscr ]]; then
            dscr=${dscr//$'\n'}
        elif [[ -n $word ]]; then
            dscr=$word
        fi
        _fzf_tab_compcap+=$dscr$'\2'$__tmp_value${word:+$'\0word\0'$word}
    done

    # tell zsh that the match is successful
    if _fzf_tab_get -t fake-compadd "fakeadd"; then
        nm=-1  # see _alternative:76
    else
        builtin compadd -U -qS '' -R _fzf_tab_remove_space ''
    fi
}

# when insert multi results, a whitespace will be added to each result
# remove left space of our fake result because I can't remove right space
# FIXME: what if the left char is not whitespace: `echo $widgets[\t`
_fzf_tab_remove_space() {
    [[ $LBUFFER[-1] == ' ' ]] && LBUFFER[-1]=''
}

: ${(A)=FZF_TAB_GROUP_COLORS=\
    $'\033[94m' $'\033[32m' $'\033[33m' $'\033[35m' $'\033[31m' $'\033[38;5;27m' $'\033[36m' \
    $'\033[38;5;100m' $'\033[38;5;98m' $'\033[91m' $'\033[38;5;80m' $'\033[92m' \
    $'\033[38;5;214m' $'\033[38;5;165m' $'\033[38;5;124m' $'\033[38;5;120m'
}
(( $+FZF_TAB_OPTS )) || FZF_TAB_OPTS=(
    --ansi   # Enable ANSI color support, necessary for showing groups
    --expect='$continuous_trigger' # For continuous completion
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\x00'  # Don't search prefix
    --layout=reverse --height='${FZF_TMUX_HEIGHT:=75%}'
    --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query will be expanded to query string at runtime.
    '--header-lines=$#headers' # $#headers will be expanded to lines of headers at runtime
)

_fzf_tab_get() {
    zstyle $1 ":fzf-tab:$_fzf_tab_curcontext" ${@:2}
}

() {
    emulate -L zsh -o extended_glob

    _fzf_tab_add_default() {
        zstyle -t ':fzf-tab:*' $1
        (( $? != 2 )) || zstyle ':fzf-tab:*' $1 ${@:2}
    }

    # Some users may still use variable
    _fzf_tab_add_default continuous-trigger ${FZF_TAB_CONTINUOUS_TRIGGER:-'/'}
    _fzf_tab_add_default fake-compadd ${FZF_TAB_FAKE_COMPADD:-default}
    _fzf_tab_add_default insert-space ${FZF_TAB_INSERT_SPACE:-true}
    _fzf_tab_add_default query-string ${(A)=FZF_TAB_QUERY:-prefix input first}
    _fzf_tab_add_default single-group ${(A)=FZF_TAB_SINGLE_GROUP:-color header}
    _fzf_tab_add_default show-group ${FZF_TAB_SHOW_GROUP:-full}
    _fzf_tab_add_default command ${FZF_TAB_COMMAND:-fzf} $FZF_TAB_OPTS
    _fzf_tab_add_default extra-opts ''
    _fzf_tab_add_default no-group-color ${FZF_TAB_NO_GROUP_COLOR:-$'\033[37m'}
    _fzf_tab_add_default group-colors $FZF_TAB_GROUP_COLORS
    _fzf_tab_add_default ignore false

    if zstyle -m ':completion:*:descriptions' format '*'; then
        _fzf_tab_add_default prefix '·'
    else
        _fzf_tab_add_default prefix ''
    fi

    unfunction _fzf_tab_add_default
}

# sets `query` to the valid query string
_fzf_tab_find_query_str() {
    local key qtype tmp query_string
    typeset -g query=
    _fzf_tab_get -a query-string query_string
    for qtype in $query_string; do
        if [[ $qtype == prefix ]]; then
            # find the longest common prefix among descriptions
            local -a keys=(${_fzf_tab_compcap%$'\2'*})
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
            local fv=${_fzf_tab_compcap[1]#*$'\2'}
            local -A v=("${(@0)fv}")
            tmp=$v[PREFIX]
            if (( $RBUFFER[(i)$v[SUFFIX]] != 1 )); then
                tmp=${tmp/%$v[SUFFIX]}
            fi
            tmp=${${tmp#$v[hpre]}#$v[apre]}
        fi
        if (( $query_string[(I)longest] )); then
            (( $#tmp > $#query )) && query=$tmp
        elif [[ -n $tmp ]]; then
            query=$tmp && break
        fi
    done
}

# pupulates array `headers` with group descriptions
_fzf_tab_get_headers() {
    typeset -ga headers=()
    local i tmp group_colors
    local -i mlen=0 len=0

    if (( $#_fzf_tab_groups == 1 )) && { ! _fzf_tab_get -m single-group "header" }; then
        return
    fi

    # calculate the max column width
    for i in $_fzf_tab_groups; do
        (( $#i > mlen )) && mlen=$#i
    done
    mlen+=1

    _fzf_tab_get -a group-colors group_colors

    for (( i=1; i<=$#_fzf_tab_groups; i++ )); do
        [[ $_fzf_tab_groups[i] == "__hide__"* ]] && continue

        if (( len + $#_fzf_tab_groups[i] > COLUMNS - 5 )); then
            headers+=$tmp
            tmp='' && len=0
        fi
        if (( len + mlen > COLUMNS - 5 )); then
            # the last column doesn't need padding
            headers+=$tmp$group_colors[i]$_fzf_tab_groups[i]$'\033[00m'
            tmp='' && len=0
        else
            tmp+=$group_colors[i]${(r:$mlen:)_fzf_tab_groups[i]}$'\033[00m'
            len+=$mlen
        fi
    done
    (( $#tmp )) && headers+=$tmp
}

_fzf_tab_colorize() {
    emulate -L zsh -o cbases -o octalzeroes

    local REPLY
    local -a reply stat lstat

    # fzf-tab-lscolors::match-by $1 lstat follow
    zstat -A lstat -L $1
    # follow symlink
    (( lstat[3] & 0170000 )) && zstat -A stat $1 2>/dev/null

    fzf-tab-lscolors::from-mode "$1" "$lstat[3]" $stat[3]
    # fall back to name
    [[ -z $REPLY ]] && fzf-tab-lscolors::from-name $1

    # If this is a symlink
    if [[ $lstat[14] ]]; then
        local sym_color=$REPLY
        local rsv_color=$REPLY
        local rsv=$lstat[14]
        # If this is not a broken symlink
        if [[ -e $rsv ]]; then
            # fzf-tab-lscolors::match-by $rsv stat
            zstat -A stat $rsv
            fzf-tab-lscolors::from-mode $rsv $stat[3]
            # fall back to name
            [[ -z $REPLY ]] && fzf-tab-lscolors::from-name $rsv
            rsv_color=$REPLY
        fi
        dpre=$'\033[0m\033['$sym_color'm'
        dsuf+=$'\033[0m -> \033['$rsv_color'm'$rsv
    else
        dpre=$'\033[0m\033['$REPLY'm'
    fi
}

# pupulates array `candidates` with completion candidates
_fzf_tab_get_candidates() {
    local dsuf dpre k _v filepath first_word show_group no_group_color prefix bs=$'\b'
    local -a list_colors group_colors tcandidates
    local -i  same_word=1 colorful=0
    local -Ua duplicate_groups=()
    local -A word_map=()

    (( $#_fzf_tab_compcap == 0 )) && return

    _fzf_tab_get -s show-group show_group
    _fzf_tab_get -a group-colors group_colors
    _fzf_tab_get -s no-group-color no_group_color
    _fzf_tab_get -s prefix prefix

    zstyle -a ":completion:$_fzf_tab_curcontext" list-colors list_colors
    local -A namecolors=(${(@s:=:)${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})
    local -A modecolors=(${(@Ms:=:)${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})

    if (( $#_fzf_tab_groups == 1 )); then
        _fzf_tab_get -m single-group prefix || prefix=''
        _fzf_tab_get -m single-group color || group_colors=($no_group_color)
    fi

    for k _v in "${(@ps:\2:)_fzf_tab_compcap}"; do
        local -A v=("${(@0)_v}")
        [[ $v[word] == ${first_word:=$v[word]} ]] || same_word=0
        # add character and color to describe the type of the files
        dsuf='' dpre=''
        if (( $+v[isfile] )); then
            filepath=${(Q)~${v[hpre]}}${(Q)${k#*$'\b'}}
            if [[ -d $filepath ]]; then
                dsuf=/
            fi
            # add color and resolve symlink if have list-colors
            # detail: http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fcomplist-Module
            if (( $#list_colors )) && [[ -a $filepath || -L $filepath ]]; then
                _fzf_tab_colorize $filepath
                colorful=1
            elif [[ -L $filepath ]]; then
                dsuf=@
            fi
        fi

        # add color to description if they have group index
        if (( $+v[group] )); then
            local color=$group_colors[$v[group]]
            # add a hidden group index at start of string to keep group order when sorting
            # first group index is for builtin sort, sencond is for GNU sort
            tcandidates+=$v[group]$'\b'$color$prefix$dpre$'\0'$v[group]$'\b'$k$'\0'$dsuf
        else
            tcandidates+=$no_group_color$dpre$'\0'$k$'\0'$dsuf
        fi

        # check group with duplicate member
        if [[ $show_group == brief ]]; then
            if (( $+word_map[$v[word]] && $+v[group] )); then
                duplicate_groups+=$v[group]            # add this group
                duplicate_groups+=$word_map[$v[word]]  # add previous group
            fi
            word_map[$v[word]]=$v[group]
        fi
    done
    (( same_word )) && tcandidates[2,-1]=()

    # sort and remove sort group or other index
    zstyle -T ":completion:$_fzf_tab_curcontext" sort
    if (( $? != 1 )); then
        if (( colorful )); then
            # if enable list_colors, we should skip the first field
            tcandidates=(${(f)"$(sort -u -t '\0' -k 2 <<< ${(pj:\n:)tcandidates})"})
        else
            tcandidates=("${(@on)tcandidates}")
        fi
    fi
    typeset -gUa candidates=("${(@)tcandidates//[0-9]#$bs}")

    # hide needless group
    if [[ $show_group == brief ]]; then
        local i indexs=({1..$#_fzf_tab_groups})
        for i in ${indexs:|duplicate_groups}; do
            # NOTE: _fzf_tab_groups is unique array
            _fzf_tab_groups[i]="__hide__$i"
        done
    fi
}

_fzf_tab_complete() {
    local -a _fzf_tab_compcap
    local -Ua _fzf_tab_groups
    local choice choices _fzf_tab_curcontext continuous_trigger bs=$'\2'

    _fzf_tab__main_complete  # must run with user options; don't move `emulate -L zsh` above this line

    emulate -L zsh -o extended_glob

    local query candidates=() headers=() command opts
    _fzf_tab_get_candidates  # sets `candidates`

    case $#candidates in
        0) return;;
        # NOTE: won't trigger continuous completion
        1) choices=("${_fzf_tab_compcap[1]%$bs*}");;
        *)
            _fzf_tab_find_query_str  # sets `query`
            _fzf_tab_get_headers     # sets `headers`
            _fzf_tab_get -s continuous-trigger continuous_trigger
            _fzf_tab_get -a command command
            _fzf_tab_get -a extra-opts opts

            export CTXT=${${_fzf_tab_compcap[1]#*$'\2'}//$'\0'/$'\2'}

            if (( $#headers )); then
                choices=$(${(eX)command} $opts <<<${(pj:\n:)headers} <<<${(pj:\n:)candidates})
            else
                choices=$(${(eX)command} $opts <<<${(pj:\n:)candidates})
            fi
            choices=(${${${(f)choices}%$'\0'*}#*$'\0'})

            unset CTXT
            ;;
    esac

    if [[ $choices[1] && $choices[1] == $continuous_trigger ]]; then
        typeset -gi _fzf_tab_continue=1
        choices[1]=()
    fi

    for choice in "$choices[@]"; do
        local -A v=("${(@0)${_fzf_tab_compcap[(r)${(b)choice}$bs*]#*$bs}}")
        local -a args=("${(@ps:\1:)v[args]}")
        [[ -z $args[1] ]] && args=()  # don't pass an empty string
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX]
        builtin compadd "${args[@]:--Q}" -Q -- "$v[word]"
    done

    compstate[list]=
    compstate[insert]=
    if (( $#choices == 1 )); then
        if _fzf_tab_get -t fake-compadd "fakeadd"; then
            compstate[insert]='1'
        else
            compstate[insert]='2'
        fi
        _fzf_tab_get -t insert-space
        (( $? )) || [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
    elif (( $#choices > 1 )); then
        compstate[insert]='all'
    fi
}

fzf-tab-complete() {
    # this name must be ugly to avoid clashes
    local -i _fzf_tab_continue=1
    while (( _fzf_tab_continue )); do
        _fzf_tab_continue=0
        IN_FZF_TAB=1
        {
            zle .fzf-tab-orig-$_fzf_tab_orig_widget
        } always {
            IN_FZF_TAB=0
        }
        zle redisplay
    done
}

zle -N fzf-tab-complete

disable-fzf-tab() {
    emulate -L zsh -o extended_glob
    (( $+_fzf_tab_orig_widget )) || return 0

    bindkey '^I' $_fzf_tab_orig_widget
    case $_fzf_tab_orig_list_grouped in
        0) zstyle ':completion:*' list-grouped false ;;
        1) zstyle ':completion:*' list-grouped true ;;
        2) zstyle -d ':completion:*' list-grouped ;;
    esac
    unset _fzf_tab_orig_widget _fzf_tab_orig_list_groupded

    # unhook compadd so that _approximate can work properply
    unfunction compadd 2>/dev/null

    functions[_main_complete]=$functions[_fzf_tab__main_complete]
    functions[_approximate]=$functions[_fzf_tab__approximate]

    # Don't remove .fzf-tab-orig-$_fzf_tab_orig_widget as we won't be able to reliably
    # create it if enable-fzf-tab is called again.
}

enable-fzf-tab() {
    emulate -L zsh -o extended_glob
    (( ! $+_fzf_tab_orig_widget )) || disable-fzf-tab

    typeset -g _fzf_tab_orig_widget="${${$(bindkey '^I')##* }:-expand-or-complete}"
    if (( ! $+widgets[.fzf-tab-orig-$_fzf_tab_orig_widget] )); then
        # Widgets that get replaced by compinit.
        local compinit_widgets=(
            complete-word
            delete-char-or-list
            expand-or-complete
            expand-or-complete-prefix
            list-choices
            menu-complete
            menu-expand-or-complete
            reverse-menu-complete
        )
        # Note: We prefix the name of the widget with '.' so that it doesn't get wrapped.
        if [[ $widgets[$_fzf_tab_orig_widget] == builtin &&
              $compinit_widgets[(Ie)$_fzf_tab_orig_widget] != 0 ]]; then
            # We are initializing before compinit and being asked to fall back to a completion
            # widget that isn't defined yet. Create our own copy of the widget ahead of time.
            zle -C .fzf-tab-orig-$_fzf_tab_orig_widget .$_fzf_tab_orig_widget _main_complete
        else
            # Copy the widget before it's wrapped by zsh-autosuggestions and zsh-syntax-highlighting.
            zle -A $_fzf_tab_orig_widget .fzf-tab-orig-$_fzf_tab_orig_widget
        fi
    fi

    zstyle -t ':completion:*' list-grouped false
    typeset -g _fzf_tab_orig_list_grouped=$?

    zstyle ':completion:*' list-grouped false
    bindkey '^I' fzf-tab-complete

    # make sure we can copy them
    autoload +X -Uz _main_complete _approximate

    # hook compadd
    functions[compadd]=$functions[_fzf_tab_compadd]

    # hook _main_complete to trigger fzf-tab
    functions[_fzf_tab__main_complete]=$functions[_main_complete]
    function _main_complete() { _fzf_tab_complete }

    # TODO: This is not a full support, see #47
    # _approximate will also hook compadd
    # let it call _fzf_tab_compadd instead of builtin compadd so that fzf-tab can capture result
    # make sure _approximate has been loaded.
    functions[_fzf_tab__approximate]=$functions[_approximate]
    function _approximate() {
        # if not called by fzf-tab, don't do anything with compadd
        (( ! IN_FZF_TAB )) || unfunction compadd
        _fzf_tab__approximate
        (( ! IN_FZF_TAB )) || functions[compadd]=$functions[_fzf_tab_compadd]
    }
}

toggle-fzf-tab() {
    emulate -L zsh -o extended_glob
    if (( $+_fzf_tab_orig_widget )); then
        disable-fzf-tab
    else
        enable-fzf-tab
    fi
}

enable-fzf-tab
zle -N toggle-fzf-tab

# restore options
(( ${#_fzf_tab_opts} )) && setopt ${_fzf_tab_opts[@]}
'builtin' 'unset' '_fzf_tab_opts'
