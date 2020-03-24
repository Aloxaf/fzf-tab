# fzf-tab

使用 fzf 取代 zsh 的内置补全选择菜单！

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [fzf-tab](#fzf-tab)
- [安装](#安装)
    - [手动](#手动)
    - [Antigen](#antigen)
    - [Zinit](#zinit)
    - [Oh-My-Zsh](#oh-my-zsh)
- [用法](#用法)
    - [配置](#配置)
        - [command](#command)
        - [extra-opts](#extra-opts)
        - [continuous-trigger](#continuous-trigger)
        - [ignore](#ignore)
        - [fake-compadd](#fake-compadd)
        - [insert-space](#insert-space)
        - [query-string](#query-string)
        - [prefix](#prefix)
        - [no-group-color](#no-group-color)
        - [single-group](#single-group)
        - [group-colors](#group-colors)
        - [show-group](#show-group)
- [与其他插件的区别](#与其他插件的区别)
- [与其他插件的兼容性](#与其他插件的兼容性)
- [相关项目](#相关项目)

<!-- markdown-toc end -->

# 安装

**注：**fzf-tab 需要在 compinit 调用之后、加载 [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) 或 [fast-syntax-highlighting](https://github.com/zdharma/fast-syntax-highlighting) 这类会 wrap 其他 widget 的插件之前加载。

## 手动

首先，clone 这个 repo

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~/somewhere
```

然后把下列代码添加到你的 `~/.zshrc`

```zsh
source ~/somewhere/fzf-tab.plugin.zsh
```

## Antigen

```zsh
antigen bundle Aloxaf/fzf-tab
```

## Zinit

```zsh
zinit light Aloxaf/fzf-tab
```

## Oh-My-Zsh

将这个 repo clone 到你的 OMZ 自定义目录，然后把 `fzf-tab` 添加到插件列表中。

```zsh
git clone https://github.com/Aloxaf/fzf-tab ~ZSH_CUSTOM/plugins/fzf-tab
```

# 用法

像平常一样按 <kbd>Tab</kbd> 就行了~

你还可以使用 <kbd>Ctrl</kdb>+<kdb>Space</kbd> 来选择多个结果，使用 <kbd>/</kbd> 来触发连续补全（在补全很深的路径时很有用）。

可用命令:

- `disable-fzf-tab`: 禁用 fzf-tab

- `enable-fzf-tab`: 启用 fzf-tab

可用绑定:

- `toggle-fzf-tab`: 切换插件状态

比如绑定到 <kbd>Ctrl</kdb>+<kdb>T</kbd>： `bindkey '^T' toggle-fzf-tab`

## 配置

fzf-tab 使用灵活的 zstyle 来进行配置。

```zsh
# 当补全命令的开关时禁用排序
zstyle ':completion:complete:*:options' sort false

# 当补全 _zlua 时，使用输入作为查询字符串
zstyle ':fzf-tab:complete:_zlua:*' query-string input

# （实验性功能，未来可能更改）
local extract="
# 提取输入（当前选择的内容）
in=\${\${\"\$(<{f})\"%\$'\0'*}#*\$'\0'}
# 获取当前补全状态的上下文（待补全内容的前面或者后面的东西）
local -A ctxt=(\"\${(@ps:\2:)CTXT}\")
"

# 补全 `kill` 命令时提供命令行参数预览
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview=$extract'ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap

# 补全 cd 时使用 exa 预览其中的内容
zstyle ':fzf-tab:complete:cd:*' extra-opts --preview=$extract'exa -1 --color=always ${~ctxt[hpre]}$in'

```

你可以通过形如 `zstyle ':fzf-tab:{context}' tag value` 的命令来配置 fzf-tab。其中 `fzf-tab` 是顶层 context。
zstyle 的更多信息详见 [zsh's doc](http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fzutil-Module)。

你可以使用 <kbd>C-x h</kbd> 来获取补全一个命令时可能的 context。

**注：**执行这个命令后，你需要使用 `enable-fzf-tab` 来重新激活 fzf-tab

```zsh
❯ rg -- # 按下 `C-x h`
tags in context :completion::complete:rg::
    operand-argument-1 options  (_arguments _rg _ripgrep)
tags in context :completion::complete:rg:options:
    options  (_arguments _rg _ripgrep)
tags in context :completion::files-enhance:::
    globbed-files  (_files _files_enhance)
```

下面是 `fzf-tab` context 中可用的 tags:

### command

模糊搜索程序的启动参数。

默认值：
```zsh
FZF_TAB_COMMAND=(
    fzf
    --ansi   # 启用 ANSI 颜色代码的支持，对于显示分组来说是必需的
    --expect='$continuous_trigger' # 连续补全
    '--color=hl:$(( $#headers == 0 ? 108 : 255 ))'
    --nth=2,3 --delimiter='\x00'  # 不搜索前缀
    --layout=reverse --height='${FZF_TMUX_HEIGHT:=75%}'
    --tiebreak=begin -m --bind=tab:down,btab:up,change:top,ctrl-space:toggle --cycle
    '--query=$query'   # $query 将在运行时扩展为查询字符串
    '--header-lines=$#headers' # $#headers 将在运行时扩展为组标题数目
)
zstyle ':fzf-tab:*' command $FZF_TAB_COMMAND
```

### extra-opts

command 的额外参数

默认值：无

### continuous-trigger

触发连续补全的按键。

默认值：`zstyle ':fzf-tab:*' continuous-trigger '/'`

### ignore

当前 context 下不要使用 fzf-tab

默认值：`zstyle ':fzf-tab:*' ignore false`

### fake-compadd

如何伪造 compadd。这项只会影响选择多个候选项时的结果。

- `default`: 使用空字符串调用 compadd。有时会导致额外空格。
- `fakeadd`: 尝试欺骗 zsh，有时会欺骗失败导致多余的候选项出现。
（比如 `sudo git \t` 不仅会显示 git 子命令还会显示当前目录下的文件）

默认值：`zstyle ':fzf-tab:*' fake-compadd default`

### insert-space

是否在结果后面自动添加空格

默认值：`zstyle ':fzf-tab:*' insert-space true`

### query-string

生成预查询字符串的策略：

- `input`: 使用用户输入，和 zsh 默认行为一致。
- `prefix`: 使用最长公共前缀作为查询字符串。
- `first`: 一个 flag，意思是第一个有效的查询字符串。
- `longest`: 另一个 flag，意思是使用最长的有效查询字符串。

默认值：`zstyle ':fzf-tab:*' query-string prefix input first`

### prefix

用来指示颜色的前缀。

默认值：`zstyle ':fzf-tab:*:' prefix '·'`

**注：** 如果没有设置 `zstyle ':completion:*:descriptions' format`，则它的值为空。

### no-group-color

如果没有分组时的颜色。

默认值：`zstyle ':fzf-tab:*' $'\033[37m'` （白色）

### single-group

当只有一个组时，需要展示哪些信息：

- `prefix`: 展示颜色前缀
- `color`: 展示分组颜色
- `header`: 展示组名

默认值：`zstyle ':fzf-tab:*' single-group color header`

### group-colors

不同组的颜色。

默认值：

```zsh
FZF_TAB_GROUP_COLORS=(
    $'\033[94m' $'\033[32m' $'\033[33m' $'\033[35m' $'\033[31m' $'\033[38;5;27m' $'\033[36m' \
    $'\033[38;5;100m' $'\033[38;5;98m' $'\033[91m' $'\033[38;5;80m' $'\033[92m' \
    $'\033[38;5;214m' $'\033[38;5;165m' $'\033[38;5;124m' $'\033[38;5;120m'
)
zstyle ':fzf-tab:*' group-colors $FZF_TAB_GROUP_COLORS
```

为了选择你喜欢的颜色，你可以使用先使用如下函数打印调色盘：

```zsh
# Usage: palette
palette() {
    local -a colors
    for i in {000..255}; do
        colors+=("%F{$i}$i%f")
    done
    print -cP $colors
}
```

然后使用这个辅助函数来获取对应颜色的转义序列：

```zsh
# Usage: printc COLOR_CODE
printc() {
    local color="%F{$1}"
    echo -E ${(qqqq)${(%)color}}
}
```

### show-group

当设置了 `zstyle ':completion:*:descriptions' format` 时，fzf-tab 会将这些描述作为组名展示在候选项的最上方。

设置为 `full` 会展示所有补全，设置为 `brief` 则仅仅展示拥有重复成员的组。

默认值：`zstyle ':fzf-tab:*' show-group full`

# 与其他插件的区别

fzf-tab 不进行“补全”，它只是展示 zsh 内置补全系统的结果。

所以它能在**任何地方**工作，(变量名、函数名、目录栈、单词中补全，等等……）。
并且你对内置补全系统的大部分配置也仍然有效。

# 与其他插件的兼容性

某些插件可能把 “^I” 绑定到它自己的 widget 上，比如 [fzf/shell/completion.zsh](https://github.com/junegunn/fzf/blob/master/shell/completion.zsh) 或 [ohmyzsh/lib/completion.zsh](https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/completion.zsh#L61-L73)。

默认情况下，fzf-tab 将调用先前绑定到 “^I” 的 widget 来获取补全候选列表。所以大部分时候都没有问题，除非 fzf-tab 在一个没有正确处理旧绑定的插件之前初始化。

所以如果你发现 fzf-tab 没有正常工作，请确保它是最后一个绑定 “^I” 的插件（如果你看不懂我在说啥，直接把 fzf-tab 放到你的插件列表最后面就可以了）。

# 相关项目

- https://github.com/lincheney/fzf-tab-completion (fzf tab completion for zsh, bash and GNU readline apps)
