# macOS dotfiles：bare Git + git-crypt

仓库位于 `~/.dotfiles.git`，工作目录是家目录。直接修改原位置的文件即可。
保留 macOS 配置；旧的 Linux 配置及 chezmoi 维护脚本不进入新仓库。
管理脚本兼容 macOS 自带的 Bash 3.2，使用系统 awk、base64 等工具，不依赖
Python。初始化中的 Homebrew、系统偏好和登录 shell 设置仍面向 macOS。
`dotfile` 是独立的 Bash CLI，可以从 Fish、Bash 或 zsh 调用；Fish 配置与补全
是可选的 shell 集成，不再承担命令入口。

## 目录

- [本机体验](#本机体验)
- [命令初始化](#命令初始化)
- [日常操作](#日常操作)
- [Homebrew 自动记录](#homebrew-自动记录)
- [Fish 配置](#fish-配置)
- [私密文件与文本密钥](#私密文件原位置明文git-内密文)
- [lazygit 加密核验](#在-lazygit-中检查加密状态)
- [密钥轮换与回退](#git-crypt-密钥轮换)
- [交互式恢复新 Mac](#交互式恢复新-mac推荐)
- [重复执行与失败重试](#重复执行与失败重试)
- [手动恢复新 Mac](#手动恢复新-mac备用)
- [迁移备份](#迁移备份)

## 本机体验

打开一个已初始化的终端，执行 `dotfile lazygit`。选择已暂存的私密文件，
Staged changes 顶部会直接显示 `[ENCRYPTED IN INDEX]`。
按大写 `E` 可以查看私密文件的完整核验结果。也可以用 `dotfile status`
和 `dotfile verify` 在命令行查看。

## 命令初始化

可执行入口是 `~/.config/dotfiles/bin/dotfile`，内部调用 Bash 核心脚本。
将它所在的 bin 目录加入当前 shell 的 PATH 即可使用。

本仓库的 Fish 配置已经包含以下内容；独立配置时也可以直接加入：

```fish
fish_add_path -g "$HOME/.config/dotfiles/bin"
```

Bash 在实际加载的启动文件中加入：交互式非登录 shell 使用 `~/.bashrc`；
macOS 的 Bash 登录 shell 通常使用 `~/.bash_profile`。

```bash
export PATH="$HOME/.config/dotfiles/bin${PATH:+:$PATH}"
```

zsh 在 `~/.zshrc` 中加入：

```zsh
export PATH="$HOME/.config/dotfiles/bin${PATH:+:$PATH}"
```

无需初始化子命令或 shell 类型变量。只有 bin 目录中的 `dotfile` 进入命令
搜索范围；它不会把 Fish 的环境配置、函数和快捷键转换成 Bash/zsh 配置。

从旧版本升级后，新开终端即可切换到可执行入口，无需重跑 setup。旧 Fish
终端中已经加载的同名函数可能仍在内存，直到该终端退出；它仍调用 Bash 核心。

## 日常操作

```fish
dotfile status
dotfile diff
dotfile add ~/.config/fish/config.fish
dotfile diff --staged
dotfile commit 'chore(fish): update shell configuration'
dotfile push
```

`dotfile` 提供独立的日常命令，Git 在内部使用，不透传 Git 子命令或参数。
执行 `dotfile help` 查看用法；fish 支持命令及路径补全。

修改管理脚本后，可运行 `bash ~/.config/dotfiles/tests/run.sh` 做回归检查。
`bash ~/.config/dotfiles/tests/lazygit.sh` 是终端界面的交互检查，按提示打开
核验弹窗后退出；两份检查均使用临时仓库和测试数据。

| 命令 | 用途 |
| --- | --- |
| `dotfile status` | 查看待提交变化和行内加密标识；不带子命令时也执行 status |
| `dotfile status --all` | 同时显示未忽略的新文件 |
| `dotfile add 文件...` | 纳入新文件，或暂存指定文件的修改、删除 |
| `dotfile add` | 暂存全部已追踪文件的修改、删除，不扫描新文件 |
| `dotfile add --encrypt 文件...` | 声明私密文件并加密暂存，也可用于已追踪的明文文件 |
| `dotfile remove 路径...` | 取消追踪、保留本地文件，并补充忽略规则 |
| `dotfile unstage [路径...]` | 撤回指定文件或全部暂存，不改动本地文件 |
| `dotfile diff [文件...]` | 查看尚未暂存的修改 |
| `dotfile diff --staged [文件...]` | 审核暂存内容 |
| `dotfile commit '说明'` | 核验加密后提交暂存内容 |
| `dotfile log --limit 10` | 查看最近的提交 |
| `dotfile pull` | 从已配置远程执行 fast-forward 更新 |
| `dotfile push` | 经过历史加密核验后推送 |
| `dotfile verify` | 核验暂存区私密文件的原始密文 |
| `dotfile lazygit` | 打开带加密核验的 lazygit |
| `dotfile checkout` | 全量检出到独立临时目录，使用普通 Git 编辑、提交和推送 |
| `dotfile key status/normalize/unlock` | 检查、规范化或解锁本地文本密钥 |
| `dotfile key rotate` | 交互式轮换密钥，自动核验、备份及异常回退 |

文件路径支持相对路径和绝对路径。新增文件直接 `dotfile add 文件`，无需修改
`.gitignore` 的允许列表，也无需 `-f`。一次只明确纳入文件；目录参数不会被递归
强制添加。密钥、仓库元数据、`.claude` 和指定本机状态路径禁止纳入。
这些保留路径由 `dotfile add`、pre-commit 和 pre-push 共用同一份规则核验。
原生 Git 强制添加或为保留路径声明加密属性，也不能提交；推送检查还会拦截
历史提交中的保留路径，即使最新版本已经移除该文件。
`.gitignore` 仍控制新文件的自动发现；已追踪文件的修改不受忽略规则影响。

`status` 和 `diff` 的私密文件行内或顶部显示黄色背景的 `[ENCRYPTED IN INDEX]`。
标识指暂存区版本，未暂存的修改仍需 add。本地 diff 可以显示明文。
加密过滤器、hook 和提交模板均配置在 bare 仓库内，普通 Git 与全局配置不变。

初始化地址固定为 `https://github.com/tokisakiyuu/dotfiles.git`。
`main` 使用 bare Git 架构；旧 chezmoi 架构及历史已迁入独立私有仓库，公开仓库
不再保留 `legacy` 分支。不要将旧布局直接合并到这个 bare 工作目录。

## 编辑仓库项目文件

HOME 使用稀疏检出：配置文件仍是原路径的实体文件；`README.md`、`.github/`、
`.gitignore` 和 `.gitattributes` 保留在 Git 中，不在 HOME 生成。忽略规则通过
此仓库专用的 `core.excludesFile` 生效，不修改全局 Git 设置。

维护 `.gitignore`、`.gitattributes`、管理脚本和 CI 等底层代码时，先运行：

```fish
dotfile checkout
```

命令输出完整检出目录的绝对路径，准备日志写入 stderr。手动进入该目录后，
使用普通 Git：

```sh
cd "/命令输出的目录"
nvim README.md .github/workflows/macos.yml
git add README.md .github/workflows/macos.yml
git commit -m 'docs: update repository instructions'
git push
```

完整副本来自本机当前分支的已提交版本，包含本机尚未推送的提交；HOME 中
未提交的修改不带入。它拥有独立 Git 对象、暂存区和配置，保留加密过滤器及
pre-commit/pre-push 检查；origin 沿用日常仓库的远程地址，普通 `git push`
直接推送到该远程。新增的忽略文件可使用普通 `git add -f` 明确纳入。

命令只准备目录并返回，不启动 shell、切换当前目录或自动同步。目录在命令
结束后继续保留，由你自行管理；确认提交已经推送后可自行删除。再次运行
`dotfile checkout` 会创建新的独立副本。

推送后回到日常工作目录运行 `dotfile pull`，即可应用更新；HOME 继续保持稀疏
检出，不会因此生成 README、CI 和策略文件。密钥轮换仍在日常工作目录执行。
此维护入口支持 macOS 和 Linux，需要 Bash、Git、git-crypt；bootstrap/setup
中的软件安装与系统设置仍面向 macOS。

撤回自动生成的策略修改的暂存时，相关文件会临时保留在 HOME，以保留修改；
重新暂存后恢复隐藏，取消暂存不会丢失加密或忽略规则。

## Homebrew 自动记录

继续使用 `brew install xx` / `brew uninstall xx`。fish 的 brew 函数在修改
软件状态之后，自动更新 `~/.config/brew/Brewfile.机器名`。
安装部分失败时也记录实际状态，并保留原命令的退出码。
帮助、查询和 dry-run 不会生成快照。清单更新后仍需 commit 和 push。

本机名称为 `macbook-m4`，保存在不受 Git 管理的
`~/.config/dotfiles/machine`，避免 pull 时切换机器身份。
首次生成的清单会被标为 intent-to-add，普通 status 也能看到它。

清单由程序生成，不要手写逻辑或注释。临时安装但尚未卸载的软件也会进入
清单。Brewfile 记录软件选择，不保证恢复到完全相同的版本。

`command brew`、绝对路径调用、其他程序内部调用 brew 会绕过 fish 函数。
函数覆盖 install/uninstall/reinstall/autoremove/tap/untap/upgrade/pin/unpin
以及修改状态的 bundle 命令。

## Fish 配置

两台设备共用 `~/.config/fish/config.fish`，公共环境变量和 PATH 设置写在其中。
私密变量继续放在受 git-crypt 保护的 `~/.config/fish/conf.d/env.secret.fish`。
运行时文件 `fish_variables` 不追踪；需要重建的公共设置写入 `config.fish`。

## 私密文件：原位置明文，Git 内密文

使用 git-crypt 的 Git clean/smudge filter。直接编辑和 add 原文件：

```fish
nvim ~/.config/fish/conf.d/env.secret.fish
dotfile add ~/.config/fish/conf.d/env.secret.fish
```

clean 在 add 时加密，smudge 在 checkout 时解密。实际配置文件保持明文，
Git 对象、提交和远程仓库保存密文。本地 diff 可以显示明文，所以不要把
私密 diff 粘贴到公开场所。文件名本身不隐藏。

根目录 `.gitattributes` 标记了三份私密配置：fish 环境变量、Git 凭据和
Jira 配置。
加密过滤器设为 required；已配置但不可用时，Git 拒绝暂存。
pre-commit hook 还会检查标记文件的暂存内容是否实际加密。

解锁密钥位于 `~/.config/dotfiles/git-crypt.key`，以 `gc1:` 开头的单行文本
保存，共 132 个字符（另有换行），权限 600，已从 Git 排除。可直接将整行
备份到密码管理器，并传到新机器。它是本仓库的无损编码，不是 git-crypt
原生格式；解锁入口在内存中还原原生格式，通过管道交给 git-crypt。
仓库内部的
`~/.dotfiles.git/git-crypt/keys/default` 也包含解锁密钥，勿公开仓库元数据。
该内部文件仍由 git-crypt 以二进制保存；你日常管理的 `.key` 文件始终是文本。
旧 chezmoi 的 age 密钥仍保留用于恢复旧仓库，与新密钥不同。

```fish
dotfile key status  # 仅检查格式，不显示密钥
pbcopy < ~/.config/dotfiles/git-crypt.key
```

不要直接把文本文件传给 `git crypt unlock`，使用 `dotfile key unlock` 或 setup。
旧二进制和完整 Base64 备份仍可导入，setup 会无损规范化为文本。
`dotfile key normalize` 可手动进行同样的转换；重复执行不改写相同内容。
文本输入两端的空白会被移除；正文必须完整。格式错误仅报告长度和非法字符
数量，不显示密钥内容。
编码不会轮换密钥，也不是额外加密。当前 96 字节随机材料直接用 Base64
表示需要 128 个字符；`gc1:` 是 4 字符格式标识。没有截断或降低密钥强度。

轮换当前版本的完整步骤见本文的[密钥轮换](#git-crypt-密钥轮换)部分。

根 `.gitattributes` 使用 Git 原生属性宏集中声明加密：

```gitattributes
[attr]private filter=git-crypt diff=git-crypt -text

.config/example/private.conf private
```

新增私密文件最直接的方式是：

```fish
dotfile add --encrypt ~/.config/example/private.conf
```

它自动补充 `private` 声明及防误删属性的保护清单，暂存密文并核验，重复执行
不重复添加规则。全程不需要修改 `.gitignore`。
`--encrypt` 用于新增加密声明；已经声明为 `private` 的文件，后续直接
`dotfile add 文件` 仍会加密，不需要重复带这个选项。`--encrypt` 必须指定文件。
也可以进入 `dotfile checkout` 创建的目录，手动编辑 `.gitattributes`，再运行
`git add -f .gitattributes .config/example/private.conf`。修改已追踪文件的加密
属性后，再用 `git add --renormalize .config/example/private.conf` 重新应用过滤器。
已有明文历史仍需单独处理，不会被重新加密。

## 在 lazygit 中检查加密状态

```fish
dotfile lazygit
```

这个入口为 bare 仓库指定 Git 目录与工作目录，并加载本仓库的 diff 渲染器。
私密文件的 diff 顶部自动显示 `[ENCRYPTED IN INDEX]` 和核验过的 blob ID；
若发现明文或缺少加密属性，则显示 `[BLOCKED]`。普通文件的 diff 保持原样。
状态指当前暂存版本；尚未暂存的修改仍需 add。

文件列表中的大写 `E` 保留为完整核验弹窗，会显示私密文件的状态、blob ID
和 git-crypt 文件头。命令行也可以运行 `dotfile verify`。

普通 diff 可能显示解密后的明文，便于审核修改；这不代表仓库保存了明文。
核验快捷键使用 `git cat-file` 读取原始对象，不经过解密 diff。
私密文件应整文件暂存，避免按行暂存或编辑 patch：git-crypt 对 git apply
这类操作存在限制。公共文件仍按平常习惯操作。

提交前核验暂存区；推送前核验将被推送的各分支/标签所包含的全部提交。
日常 add/commit 的加密核验成功时静默，失败时显示原因并阻止操作；
完整核验报告使用 `dotfile verify` 查看。
即使最新提交已修好，历史中含有明文私密配置也会阻止推送。
这两个检查都不打印私密明文。lazygit 的 WIP 自动跳过 hook 功能已在本仓库
入口中关闭。不要手动跳过 hook。

`private-files` 保护已登记的私密文件，防止误删属性后悄悄提交明文。
`dotfile add --encrypt` 自动登记；手动通过 `.gitattributes` 标记的文件也会核验加密。
检查只能保护已标记或列入清单的文件。

CI 会先检查真实提交及其全部可达历史，通过后才创建测试仓库、运行原有回归和
安装测试。检查会汇总历史中的私密清单和加密属性，避免替换测试数据、删除声明
或只修复最新版本掩盖历史明文。完整检出中的手动入口是
`bash .github/scripts/check-source-encryption.sh HEAD`；浅克隆会被拒绝。
这道检查不需要个人解密密钥，只验证 Git 原始对象的密文格式；解锁后的
`dotfile verify` 才能进一步验证暂存密文可由本机密钥解密。

## git-crypt 密钥轮换

只需执行：

```fish
dotfile key rotate
```

运行后仅在开始时确认一次。程序会生成新密钥、重新加密当前已追踪版本、
解密核验并切换仓库，同时备份旧仓库和旧密钥，直接覆盖
`~/.config/dotfiles/git-crypt.key`（权限 600，已从 Git 排除）。
完成后显示密钥文件路径并退出，不操作剪贴板，也不等待再次确认。
回到 shell 后，读取这个文件，将其中的单行新密钥备份到安全媒介即可。
工作文件仍是明文，新密文进入暂存区，由你决定何时提交和推送。

如果轮换意外中断，重新运行同一条命令可恢复并继续使用已准备的密钥。
也可以取消未完成的准备：

```fish
dotfile key rotate --cancel
```

取消会恢复原路径下的旧文本密钥，仓库继续使用旧密钥。切换异常会自动恢复
旧仓库及旧文本密钥；断电或强制退出
留下的切换状态，会在下次运行 `dotfile key rotate` 时恢复。备份位于 Git
忽略的 `~/.local/state/dotfiles/` 下，完成时会显示具体路径。

尚未首次提交时可以直接轮换，不必先创建旧密钥的提交。如果有未暂存修改，
先用 `dotfile add` 暂存。当前支持默认对称密钥，不支持 named keys 或 GPG 授权。

轮换会保留已有历史，旧提交仍需旧密钥。新密钥不能解密旧版本，也无法撤销
别人已经持有的旧密钥和旧历史。如果轮换是因为泄漏，历史中的 API token、
密码等仍需在对应服务更换。其他机器更新到新提交时也需要新的文本密钥。
本机 diff 会自动尝试备份中的旧密钥读取历史版本，因此请保留轮换备份。

参考：[官方限制](https://github.com/AGWA/git-crypt#limitations)。

## 交互式恢复新 Mac（推荐）

`bootstrap.sh` 是独立恢复入口，可从系统终端运行：

```sh
curl -fsSL https://raw.githubusercontent.com/tokisakiyuu/dotfiles/main/.config/dotfiles/bootstrap.sh | bash
```

`setup.sh` 和日常辅助脚本依赖配套文件，应从已安装的文件路径执行。

入口无需密钥命令参数。交互内容包括：

- 仓库地址固定为 `https://github.com/tokisakiyuu/dotfiles.git`，不接受参数、
  环境变量或交互覆盖。
- 机器名：默认读取 `scutil --get LocalHostName`，按回车接受，也可覆盖。
- git-crypt 密钥：隐藏输入文件路径，或直接粘贴 `gc1:` 开头的单行文本；
  也兼容旧完整 Base64。不回显、不进入命令历史、不作为外部进程参数传递。
- 是否安装该机器 Brewfile 中的软件、应用 macOS 偏好、将登录 shell 设为 fish。

在旧 Mac 将文本密钥复制到剪贴板：

```sh
pbcopy < "$HOME/.config/dotfiles/git-crypt.key"
```

密钥内容不会打印到终端或写进命令历史。新 Mac 输入完成后，临时文本文件会
被清理；持久文本密钥仅保存在本机忽略路径，权限为 600。

脚本自动 clone、checkout、放置密钥并调用 setup。所有交互从 `/dev/tty`
读取，因此 `curl | bash` 的管道不会吞掉密码输入或软件清单编辑。
不会强制覆盖现有配置文件或复用不同 origin 的仓库。重跑未完成的初始化时，
采用本次输入的有效密钥，替换前备份上次留下的本机密钥副本；已启用的仓库
密钥与输入不同时会停止。

首次遇到新机器名时，会以已有 Brewfile 为模板打开 vi，让你在安装前编辑。
有多份模板时先选择一份；新清单会标为 intent-to-add，便于之后提交。
不安装完整软件清单时仍需 git-crypt；选择 fish 还会安装其共享配置所需工具。
bootstrap/setup 安装期间为 Homebrew 设置 `HOMEBREW_NO_ASK=1`，省去重复的
软件安装确认；该设置仅在初始化过程内生效，管理员密码等独立验证仍需交互。
初始化结束自动执行加密核验，不必再手动运行 verify。

脚本本身不包含密钥，可以单独公开托管；私有配置仓库仍需 Git 访问权限。

## 重复执行与失败重试

初始化脚本按目标状态收敛：同一组选项重复执行，不更换已启用的仓库密钥，
不覆盖本地配置修改，也不重复追加登录 shell。Homebrew 原生的安装与升级属于预期行为，
不承诺软件版本保持不变。

- bootstrap 复用同一 origin 的现有 bare 仓库。初始化未完成解锁时，会获取
  最新 main 并只允许快进更新；历史分叉、重叠修改、不同密钥或 origin 会停止。
- 密钥先写入受忽略规则保护、权限 600 的临时文件，再安装到目标路径。
- setup 使用 macOS lockf 互斥锁；同时运行第二份会退出，进程结束后系统自动
  释放锁。保留的锁文件不代表初始化仍在运行，不必手工删除。
- 机器身份与内容相同的 Brewfile 不重复改写。重复 source fish 配置不会
  累加 Rust/Cargo 的 PATH 项。
- 已经解锁的私密文件不重新 checkout。若解锁中断留下密文，先完整解密并
  校验成功，再替换该文件；已有明文修改会保留。
- 首次安装解密工具期间，暂存尚未解密的 Git 私密配置，避免安装程序将密文
  当作 Git 配置读取；安装后还原并解锁，失败或再次运行时也会恢复暂存文件。
- tmux 依赖先在临时目录完整下载和解压，再替换目标；下载失败可以重试。
  已有的不完整目录会保留备份，完整目录不会重复下载。
- Finder 设置已经符合目标时，跳过写入，也不再关闭系统设置。

幂等范围是初始化、恢复和安装辅助脚本；日常 Git 命令保留 Git 原本的行为。
运行中的脚本仍可能因权限、网络或本地冲突退出；修正原因后可重新执行。

## 手动恢复新 Mac（备用）

在新 Mac 的 bash 中执行：

```sh
git clone --bare https://github.com/tokisakiyuu/dotfiles.git "$HOME/.dotfiles.git"
git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" checkout
```

如果有现存文件冲突，备份并移开明确冲突的文件后重试，不要强制覆盖家目录。
此时私密配置暂时是密文，解锁前不要启动会读取它们的 fish。

将独立备份的密钥放到 `~/.config/dotfiles/git-crypt.key`，chmod 600。
恢复相同机器角色时执行：

```sh
bash ~/.config/dotfiles/setup.sh macbook-m4
```

新 Mac mini 的安装列表还没有实际数据。可先复制 MacBook 清单，编辑掉
不需要的软件，再运行：

```sh
cp ~/.config/brew/Brewfile.macbook-m4 ~/.config/brew/Brewfile.macmini-m4
# 编辑 Brewfile.macmini-m4 后再安装。
bash ~/.config/dotfiles/setup.sh macmini-m4
```

共享 shell 依赖 fish、starship、zoxide、neovim；加密功能依赖 git-crypt。
setup 安装 Homebrew、git-crypt 和 fish，解锁私密文件，按机器清单安装软件，
安装 oh-my-tmux，应用原有 Finder 设置，设置 fish 为登录 shell。
修改登录 shell 时可能要求输入 macOS 密码。不会执行软件清理。

只配置机器身份和 Git hook，不安装软件或修改系统设置：

```sh
bash ~/.config/dotfiles/setup.sh macmini-m4 --configure-only
```

如果只需要解锁，先安装 git-crypt，然后在家目录执行：

```sh
bash "$HOME/.config/dotfiles/key-file.sh" unlock
```

新 clone 上先解锁再修改私密配置。不要在配置仍为密文时让程序重写它们。
setup 会在自己的进程内临时跳过全局 Git 配置，让 Git 在凭据文件仍为密文时
也能完成解锁；不会修改你的全局配置或当前 shell 环境。
tmux 使用相对符号链接；外部 oh-my-tmux 由 setup 下载。

## 迁移备份

旧源仓库仍在 `~/.local/share/chezmoi`。修改前备份的位置记录在本机文件
`~/.config/dotfiles/backup-location`。迁移后不要再执行 `chezmoi apply`，
它会把旧脚本和旧配置覆盖回来。

手动 setup 也支持不传机器名：首次取系统 LocalHostName，之后沿用本机记录。
可使用 `--skip-packages`、`--skip-defaults`、`--keep-shell` 跳过对应步骤；
`--configure-only` 仅恢复 bare 仓库局部配置与机器身份。
