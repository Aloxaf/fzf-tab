# temporarily change options
'builtin' 'local' '-a' '_fzf_tab_opts'
[[ ! -o 'aliases'         ]] || _fzf_tab_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _fzf_tab_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _fzf_tab_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

zmodload zsh/zutil
zmodload -F zsh/stat b:zstat

0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
FZF_TAB_HOME=${0:h}

autoload -Uz $FZF_TAB_HOME/ftb-tmux-popup $FZF_TAB_HOME/lib/-ftb*
source ${0:h}/lib/zsh-ls-colors/ls-colors.zsh fzf-tab-lscolors

typeset -g fzf_tab_preview_init="
local -a _ftb_compcap=(\"\${(@f)\"\$(</tmp/fzf-tab/compcap.$$)\"}\")
local -a _ftb_groups=(\"\${(@f)\"\$(</tmp/fzf-tab/groups.$$)\"}\")
local bs=\$'\2'
# get descriptoin
local desc=\${\${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
# get ctxt for current completion
local -A ctxt=(\"\${(@0)\${_ftb_compcap[(r)\${(b)desc}\$bs*]#*\$bs}}\")
# get group
local group=\$_ftb_groups[\$ctxt[group]]
# get real path if it is file
if (( \$+ctxt[isfile] )); then
  local realpath=\${(Qe)~\${:-\${ctxt[IPREFIX]}\${ctxt[hpre]}}}\${(Q)desc}
fi
# get original word
local word=\$ctxt[word]
"

_fzf_tab_debug() {
  echo -E $'\n'${(qqqq)1}$'\n'
}

# thanks Valodim/zsh-capture-completion
_fzf_tab_compadd() {
  # parse all options
  local -A apre hpre dscrs _oad
  local -a isfile _opts __ expl
  zparseopts -E -a _opts P:=apre p:=hpre d:=dscrs X+:=expl O:=_oad A:=_oad D:=_oad f=isfile \
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
  local ret=$?
  if (( $#__hits == 0 )); then
    return $ret
  fi

  # store $curcontext for furthur usage
  _ftb_curcontext=${curcontext#:}

  # only store the fist `-X`
  expl=$expl[2]

  # keep order of group description
  [[ -n $expl ]] && _ftb_groups+=$expl

  # store these values in _ftb_compcap
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
    __tmp_value+=$'\0group\0'$_ftb_groups[(ie)$expl]
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
    _ftb_compcap+=$dscr$'\2'$__tmp_value$'\0word\0'$word
  done

  # tell zsh that the match is successful
  builtin compadd -U -qS '' -R _fzf_tab_remove_space ''
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

_fzf_tab_get() {
  zstyle $1 ":fzf-tab:$_ftb_curcontext" ${@:2}
}

() {
  emulate -L zsh -o extended_glob

  _fzf_tab_add_default() {
    zstyle -t ':fzf-tab:*' $1
    (( $? != 2 )) || zstyle ':fzf-tab:*' $1 ${@:2}
  }

  # Some users may still use variable
  _fzf_tab_add_default continuous-trigger ${FZF_TAB_CONTINUOUS_TRIGGER:-'/'}
  _fzf_tab_add_default query-string ${(A)=FZF_TAB_QUERY:-prefix input first}
  _fzf_tab_add_default single-group ${(A)=FZF_TAB_SINGLE_GROUP:-color header}
  _fzf_tab_add_default show-group ${FZF_TAB_SHOW_GROUP:-full}
  _fzf_tab_add_default no-group-color ${FZF_TAB_NO_GROUP_COLOR:-$'\033[37m'}
  _fzf_tab_add_default group-colors $FZF_TAB_GROUP_COLORS
  _fzf_tab_add_default print-query alt-enter
  _fzf_tab_add_default popup-pad 0 0

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
      local -a keys=(${_ftb_compcap%$'\2'*})
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
      local fv=${_ftb_compcap[1]#*$'\2'}
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

  if (( $#_ftb_groups == 1 )) && { ! _fzf_tab_get -m single-group "header" }; then
    return
  fi

  # calculate the max column width
  for i in $_ftb_groups; do
    (( $#i > mlen )) && mlen=$#i
  done
  mlen+=1

  _fzf_tab_get -a group-colors group_colors

  for (( i=1; i<=$#_ftb_groups; i++ )); do
    [[ $_ftb_groups[i] == "__hide__"* ]] && continue

    if (( len + $#_ftb_groups[i] > COLUMNS - 5 )); then
      headers+=$tmp
      tmp='' && len=0
    fi
    if (( len + mlen > COLUMNS - 5 )); then
      # the last column doesn't need padding
      headers+=$tmp$group_colors[i]$_ftb_groups[i]$'\033[00m'
      tmp='' && len=0
    else
      tmp+=$group_colors[i]${(r:$mlen:)_ftb_groups[i]}$'\033[00m'
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
  zstat -A lstat -L -- $1
  # follow symlink
  (( lstat[3] & 0170000 )) && zstat -A stat -- $1 2>/dev/null

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
      zstat -A stat -- $rsv
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
  local -a list_colors group_colors tcandidates reply match mbegin mend
  local -i  same_word=1 colorful=0
  local -Ua duplicate_groups=()
  local -A word_map=()

  (( $#_ftb_compcap == 0 )) && return

  _fzf_tab_get -s show-group show_group
  _fzf_tab_get -a group-colors group_colors
  _fzf_tab_get -s no-group-color no_group_color
  _fzf_tab_get -s prefix prefix

  zstyle -a ":completion:$_ftb_curcontext" list-colors list_colors
  if (( $+builtins[fzf-tab-colorize] )); then
    fzf-tab-colorize -c list_colors
  else
    local -A namecolors=(${(@s:=:)${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})
    local -A modecolors=(${(@Ms:=:)${(@s.:.)list_colors}:#[[:alpha:]][[:alpha:]]=*})
  fi

  if (( $#_ftb_groups == 1 )); then
    _fzf_tab_get -m single-group prefix || prefix=''
    _fzf_tab_get -m single-group color || group_colors=($no_group_color)
  fi

  for k _v in "${(@ps:\2:)_ftb_compcap}"; do
    local -A v=("${(@0)_v}")
    [[ $v[word] == ${first_word:=$v[word]} ]] || same_word=0
    # add character and color to describe the type of the files
    dsuf='' dpre=''
    if (( $+v[isfile] )); then
      filepath=${v[IPREFIX]}${v[hpre]}$v[word]
      filepath=${(Q)${(e)~filepath}}
      if (( $#list_colors && $+builtins[fzf-tab-colorize] )); then
        fzf-tab-colorize $filepath 2>/dev/null
        dpre=$reply[2]$reply[1] dsuf=$reply[2]$reply[3]
        if [[ $reply[4] ]]; then
          dsuf+=" -> $reply[4]"
        fi
        [[ $dpre ]] && colorful=1
      else
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
        if [[ $options[list_types] == off ]]; then
          dsuf=''
        fi
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
  zstyle -T ":completion:$_ftb_curcontext" sort
  if (( $? != 1 )); then
    if (( colorful )); then
      # if enable list_colors, we should skip the first field
      if [[ ${commands[sort]:A:t} != (|busybox*) ]]; then
        # this is faster but doesn't work if `find` is from busybox
        tcandidates=(${(f)"$(command sort -u -t '\0' -k 2 <<< ${(pj:\n:)tcandidates})"})
      else
        # slower but portable
        tcandidates=(${(@o)${(@)tcandidates:/(#b)([^$'\0']#)$'\0'(*)/$match[2]$'\0'$match[1]}})
        tcandidates=(${(@)tcandidates/(#b)(*)$'\0'([^$'\0']#)/$match[2]$'\0'$match[1]})
      fi
    else
      tcandidates=("${(@o)tcandidates}")
    fi
  fi
  typeset -gUa candidates=("${(@)tcandidates//[0-9]#$bs}")

  # hide needless group
  if [[ $show_group == brief && -n ${_ftb_groups[@]} ]]; then
    local i indexs=({1..$#_ftb_groups})
    for i in ${indexs:|duplicate_groups}; do
      # NOTE: _ftb_groups is unique array
      _ftb_groups[i]="__hide__$i"
    done
  fi
}

_fzf_tab_complete() {
  local -a _ftb_compcap
  local -Ua _ftb_groups
  local choice choices _ftb_curcontext continuous_trigger bs=$'\2' nul=$'\0'

  _fzf_tab__main_complete "$@" # must run with user options; don't move `emulate -L zsh` above this line

  emulate -L zsh -o extended_glob

  local query candidates=() headers=() command opts
  _fzf_tab_get_candidates  # sets `candidates`

  case $#candidates in
    0) return;;
    # NOTE: won't trigger continuous completion
    1) choices=("EXPECT_KEY" "${_ftb_compcap[1]%$bs*}");;
    *)
      _fzf_tab_find_query_str  # sets `query`
      _fzf_tab_get_headers     # sets `headers`
      zstyle -s ":fzf-tab:$_ftb_curcontext" continuous-trigger continus_trigger || continous_trigger=/
      zstyle -s ":fzf-tab:$_ftb_curcontext" print-query print_query || print_query=alt-enter

      print -l $headers $candidates | -ftb-fzf

      # insert query string directly
      if [[ $choices[2] == $print_query ]] || [[ -n $choices[1] && $#choices == 1 ]] ; then
        local -A v=("${(@0)${_ftb_compcap[1]}}")
        local -a args=("${(@ps:\1:)v[args]}")
        [[ -z $args[1] ]] && args=()  # don't pass an empty string
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX]
        # NOTE: should I use `-U` here?, ../f\tabcd -> ../abcd
        builtin compadd "${args[@]:--Q}" -Q -- $choices[1]

        compstate[list]= compstate[insert]='2'
        [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
        return
      fi
      choices[1]=()

      choices=("${(@)${(@)choices%$nul*}#*$nul}")

      unset CTXT
      ;;
  esac

  if [[ $choices[1] && $choices[1] == $continuous_trigger ]]; then
    typeset -gi _fzf_tab_continue=1
  fi
  choices[1]=()

  for choice in "$choices[@]"; do
    local -A v=("${(@0)${_ftb_compcap[(r)${(b)choice}$bs*]#*$bs}}")
    local -a args=("${(@ps:\1:)v[args]}")
    [[ -z $args[1] ]] && args=()  # don't pass an empty string
    IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX]
    builtin compadd "${args[@]:--Q}" -Q -- "$v[word]"
  done

  compstate[list]=
  compstate[insert]=
  if (( $#choices == 1 )); then
    compstate[insert]='2'
    [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
  elif (( $#choices > 1 )); then
    compstate[insert]='all'
  fi
}

fzf-tab-complete() {
  # this name must be ugly to avoid clashes
  local -i _fzf_tab_continue=1
  while (( _fzf_tab_continue )); do
    _fzf_tab_continue=0
    local IN_FZF_TAB=1
    {
      zle .fzf-tab-orig-$_fzf_tab_orig_widget
    } always {
      IN_FZF_TAB=0
    }
    if (( _fzf_tab_continue )); then
      zle .split-undo
      zle .reset-prompt
      zle -R
    else
      zle redisplay
    fi
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
  function _main_complete() { _fzf_tab_complete "$@" }

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

build-fzf-tab-module() {
  local MACOS
  if [[ ${OSTYPE} == darwin* ]]; then
    MACOS=true
  fi
  pushd $FZF_TAB_HOME/modules
  CPPFLAGS=-I/usr/local/include CFLAGS="-g -Wall -O3" LDFLAGS=-L/usr/local/lib ./configure --disable-gdbm --without-tcsetpgrp ${MACOS:+DL_EXT=bundle}
  make -j
  popd
}

() {
  if [[ -e $FZF_TAB_HOME/modules/Src/aloxaf/fzftab.so ]]; then
    module_path+=("$FZF_TAB_HOME/modules/Src")
    zmodload aloxaf/fzftab

    if [[ $FZF_TAB_MODULE_VERSION != "0.1.1" ]]; then
      zmodload -u aloxaf/fzftab
      local rebuild
      print -Pn "%F{yellow}fzftab module needs to be rebuild, rebuild now?[Y/n]:%f"
      read -q rebuild
      if [[ $rebuild == y ]]; then
        build-fzf-tab-module
        zmodload aloxaf/fzftab
      fi
    fi
  fi
}

enable-fzf-tab
zle -N toggle-fzf-tab

# restore options
(( ${#_fzf_tab_opts} )) && setopt ${_fzf_tab_opts[@]}
'builtin' 'unset' '_fzf_tab_opts'
