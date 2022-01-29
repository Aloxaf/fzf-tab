# temporarily change options
'builtin' 'local' '-a' '_ftb_opts'
[[ ! -o 'aliases'         ]] || _ftb_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || _ftb_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || _ftb_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

# thanks Valodim/zsh-capture-completion
-ftb-compadd() {
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
  local -a keys=(apre hpre PREFIX SUFFIX IPREFIX ISUFFIX)
  local key expanded __tmp_value=$'<\0>' # placeholder
  for key in $keys; do
    expanded=${(P)key}
    if [[ -n $expanded ]]; then
      __tmp_value+=$'\0'$key$'\0'$expanded
    fi
  done
  if [[ -n $expl ]]; then
    # store group index
    __tmp_value+=$'\0group\0'$_ftb_groups[(ie)$expl]
  fi
  if [[ -n $isfile ]]; then
    # NOTE: need a extra ${} here or ~ expansion won't work
    __tmp_value+=$'\0realdir\0'${${(Qe)~${:-$IPREFIX$hpre}}}
  fi
  _opts+=("${(@kv)apre}" "${(@kv)hpre}" $isfile)
  __tmp_value+=$'\0args\0'${(pj:\1:)_opts}

  if (( $+builtins[fzf-tab-compcap-generate] )); then
    fzf-tab-compcap-generate __hits __dscr __tmp_value
  else
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
  fi

  # tell zsh that the match is successful
  builtin compadd -U -qS '' -R -ftb-remove-space ''
}

# when insert multi results, a whitespace will be added to each result
# remove left space of our fake result because I can't remove right space
# FIXME: what if the left char is not whitespace: `echo $widgets[\t`
-ftb-remove-space() {
  [[ $LBUFFER[-1] == ' ' ]] && LBUFFER[-1]=''
}

-ftb-zstyle() {
  zstyle $1 ":fzf-tab:$_ftb_curcontext" ${@:2}
}

-ftb-complete() {
  local -a _ftb_compcap
  local -Ua _ftb_groups
  local choice choices _ftb_curcontext continuous_trigger print_query accept_line bs=$'\2' nul=$'\0'
  local ret=0

  # must run with user options; don't move `emulate -L zsh` above this line
  (( $+builtins[fzf-tab-compcap-generate] )) && fzf-tab-compcap-generate -i
  COLUMNS=500 _ftb__main_complete "$@" || ret=$?
  (( $+builtins[fzf-tab-compcap-generate] )) && fzf-tab-compcap-generate -o

  emulate -L zsh -o extended_glob

  local _ftb_query _ftb_complist=() _ftb_headers=() command opts
  -ftb-generate-complist # sets `_ftb_complist`

  -ftb-zstyle -s continuous-trigger continuous_trigger || {
    [[ $OSTYPE == msys ]] && continuous_trigger=// || continuous_trigger=/
  }

  case $#_ftb_complist in
    0) return 1;;
    1)
      choices=("EXPECT_KEY" "${_ftb_compcap[1]%$bs*}")
      if (( _ftb_continue_last )); then
        choices[1]=$continuous_trigger
      fi
      ;;
    *)
      -ftb-generate-query      # sets `_ftb_query`
      -ftb-generate-header     # sets `_ftb_headers`
      -ftb-zstyle -s print-query print_query || print_query=alt-enter
      -ftb-zstyle -s accept-line accept_line

      choices=("${(@f)"$(builtin print -rl -- $_ftb_headers $_ftb_complist | -ftb-fzf)"}")
      ret=$?
      # choices=(query_string expect_key returned_word)

      # insert query string directly
      if [[ $choices[2] == $print_query ]] || [[ -n $choices[1] && $#choices == 1 ]] ; then
        local -A v=("${(@0)${_ftb_compcap[1]}}")
        local -a args=("${(@ps:\1:)v[args]}")
        [[ -z $args[1] ]] && args=()  # don't pass an empty string
        IPREFIX=$v[IPREFIX] PREFIX=$v[PREFIX] SUFFIX=$v[SUFFIX] ISUFFIX=$v[ISUFFIX]
        # NOTE: should I use `-U` here?, ../f\tabcd -> ../abcd
        builtin compadd "${args[@]:--Q}" -Q -- $choices[1]

        compstate[list]=
        compstate[insert]=
        if (( $#choices[1] > 0 )); then
            compstate[insert]='2'
            [[ $RBUFFER == ' '* ]] || compstate[insert]+=' '
        fi
        return $ret
      fi
      choices[1]=()

      choices=("${(@)${(@)choices%$nul*}#*$nul}")

      unset CTXT
      ;;
  esac

  if [[ -n $choices[1] && $choices[1] == $continuous_trigger ]]; then
    typeset -gi _ftb_continue=1
    typeset -gi _ftb_continue_last=1
  fi

  if [[ -n $choices[1] && $choices[1] == $accept_line ]]; then
    typeset -gi _ftb_accept=1
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
  return $ret
}

fzf-tab-debug() {
  (( $+_ftb_debug_cnt )) || typeset -gi _ftb_debug_cnt
  local tmp=${TMPPREFIX:-/tmp/zsh}-$$-fzf-tab-$(( ++_ftb_debug_cnt )).log
  local -i debug_fd=-1 IN_FZF_TAB=1
  {
    exec {debug_fd}>&2 2>| $tmp
    local -a debug_indent; debug_indent=( '%'{3..20}'(e. .)' )
    local PROMPT4 PS4="${(j::)debug_indent}+%N:%i> "
    setopt xtrace
    : $ZSH_NAME $ZSH_VERSION
    zle .fzf-tab-orig-$_ftb_orig_widget
    unsetopt xtrace
    if (( debug_fd != -1 )); then
      zle -M "fzf-tab-debug: Trace output left in $tmp"
    fi
  } always {
    (( debug_fd != -1 )) && exec 2>&$debug_fd {debug_fd}>&-
  }
}

fzf-tab-complete() {
  # this name must be ugly to avoid clashes
  local -i _ftb_continue=1 _ftb_continue_last=0 _ftb_accept=0 ret=0
  # hide the cursor until finishing completion, so that users won't see cursor up and down
  # NOTE: MacOS Terminal doesn't support civis & cnorm
  echoti civis >/dev/tty 2>/dev/null
  while (( _ftb_continue )); do
    _ftb_continue=0
    local IN_FZF_TAB=1
    {
      zle .fzf-tab-orig-$_ftb_orig_widget
      ret=$?
    } always {
      IN_FZF_TAB=0
    }
    if (( _ftb_continue )); then
      zle .split-undo
      zle .reset-prompt
      zle -R
      zle fzf-tab-dummy
    fi
  done
  echoti cnorm >/dev/tty 2>/dev/null
  zle .redisplay
  (( _ftb_accept )) && zle .accept-line
  return $ret
}

# this function does nothing, it is used to be wrapped by other plugins like f-sy-h.
# this make it possible to call the wrapper function without causing any other side effects.
fzf-tab-dummy() { }

zle -N fzf-tab-debug
zle -N fzf-tab-complete
zle -N fzf-tab-dummy

disable-fzf-tab() {
  emulate -L zsh -o extended_glob
  (( $+_ftb_orig_widget )) || return 0

  bindkey '^I' $_ftb_orig_widget
  case $_ftb_orig_list_grouped in
    0) zstyle ':completion:*' list-grouped false ;;
    1) zstyle ':completion:*' list-grouped true ;;
    2) zstyle -d ':completion:*' list-grouped ;;
  esac
  unset _ftb_orig_widget _ftb_orig_list_groupded

  # unhook compadd so that _approximate can work properply
  unfunction compadd 2>/dev/null

  functions[_main_complete]=$functions[_ftb__main_complete]
  functions[_approximate]=$functions[_ftb__approximate]

  # Don't remove .fzf-tab-orig-$_ftb_orig_widget as we won't be able to reliably
  # create it if enable-fzf-tab is called again.
}

enable-fzf-tab() {
  emulate -L zsh -o extended_glob
  (( ! $+_ftb_orig_widget )) || disable-fzf-tab

  typeset -g _ftb_orig_widget="${${$(builtin bindkey '^I')##* }:-expand-or-complete}"
  if (( ! $+widgets[.fzf-tab-orig-$_ftb_orig_widget] )); then
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
    if [[ $widgets[$_ftb_orig_widget] == builtin &&
            $compinit_widgets[(Ie)$_ftb_orig_widget] != 0 ]]; then
      # We are initializing before compinit and being asked to fall back to a completion
      # widget that isn't defined yet. Create our own copy of the widget ahead of time.
      zle -C .fzf-tab-orig-$_ftb_orig_widget .$_ftb_orig_widget _main_complete
    else
      # Copy the widget before it's wrapped by zsh-autosuggestions and zsh-syntax-highlighting.
      zle -A $_ftb_orig_widget .fzf-tab-orig-$_ftb_orig_widget
    fi
  fi

  zstyle -t ':completion:*' list-grouped false
  typeset -g _ftb_orig_list_grouped=$?

  zstyle ':completion:*' list-grouped false
  bindkey -M emacs '^I'  fzf-tab-complete
  bindkey -M viins '^I'  fzf-tab-complete
  bindkey -M emacs '^X.' fzf-tab-debug
  bindkey -M viins '^X.' fzf-tab-debug

  # make sure we can copy them
  autoload +X -Uz _main_complete _approximate

  # hook compadd
  functions[compadd]=$functions[-ftb-compadd]

  # hook _main_complete to trigger fzf-tab
  functions[_ftb__main_complete]=$functions[_main_complete]
  function _main_complete() { -ftb-complete "$@" }

  # TODO: This is not a full support, see #47
  # _approximate will also hook compadd
  # let it call -ftb-compadd instead of builtin compadd so that fzf-tab can capture result
  # make sure _approximate has been loaded.
  functions[_ftb__approximate]=$functions[_approximate]
  function _approximate() {
    # if not called by fzf-tab, don't do anything with compadd
    (( ! IN_FZF_TAB )) || unfunction compadd
    _ftb__approximate
    (( ! IN_FZF_TAB )) || functions[compadd]=$functions[-ftb-compadd]
  }
}

toggle-fzf-tab() {
  emulate -L zsh -o extended_glob
  if (( $+_ftb_orig_widget )); then
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
  CPPFLAGS=-I/usr/local/include CFLAGS="-g -Wall -O2" LDFLAGS=-L/usr/local/lib ./configure --disable-gdbm --without-tcsetpgrp ${MACOS:+DL_EXT=bundle}
  make -j$(nproc)
  popd
}

zmodload zsh/zutil
zmodload zsh/mapfile
zmodload -F zsh/stat b:zstat

0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"
FZF_TAB_HOME="${0:A:h}"

source "$FZF_TAB_HOME"/lib/zsh-ls-colors/ls-colors.zsh fzf-tab-lscolors

typeset -ga _ftb_group_colors=(
  $'\x1b[94m' $'\x1b[32m' $'\x1b[33m' $'\x1b[35m' $'\x1b[31m' $'\x1b[38;5;27m' $'\x1b[36m'
  $'\x1b[38;5;100m' $'\x1b[38;5;98m' $'\x1b[91m' $'\x1b[38;5;80m' $'\x1b[92m'
  $'\x1b[38;5;214m' $'\x1b[38;5;165m' $'\x1b[38;5;124m' $'\x1b[38;5;120m'
)

# init
() {
  emulate -L zsh -o extended_glob

  fpath+=($FZF_TAB_HOME/lib)

  autoload -Uz -- $FZF_TAB_HOME/lib/-#ftb*(:t)

  if (( $+FZF_TAB_COMMAND || $+FZF_TAB_OPTS || $+FZF_TAB_QUERY || $+FZF_TAB_SINGLE_GROUP || $+fzf_tab_preview_init )) \
       || zstyle -m ":fzf-tab:*" command '*' \
       || zstyle -m ":fzf-tab:*" extra-opts '*'; then
    print -P "%F{red}%B[fzf-tab] Sorry, your configuration is not supported anymore\n" \
          "See https://github.com/Aloxaf/fzf-tab/pull/132 for more information%f%b"
  fi

  if [[ -n $FZF_TAB_HOME/modules/Src/aloxaf/fzftab.(so|bundle)(#qN) ]]; then
    module_path+=("$FZF_TAB_HOME/modules/Src")
    zmodload aloxaf/fzftab

    if [[ $FZF_TAB_MODULE_VERSION != "0.2.2" ]]; then
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
(( ${#_ftb_opts} )) && setopt ${_ftb_opts[@]}
'builtin' 'unset' '_ftb_opts'
