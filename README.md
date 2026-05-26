# dotfiles

用 [chezmoi](https://www.chezmoi.io/) 管理的个人 dotfiles，目标平台 macOS（Apple Silicon 与 Intel 都兼容）。

核心约定：**`~` 是事实来源，不是 source**。日常工作流是改 `~` 下的文件（或被程序自动改），然后用 `chezmoi re-add` 把变化吸回 source，再 commit / push。这跟"先改 source，apply 到 ~"的传统 chezmoi 用法是反过来的。

---

## 仓库结构

```
setup.sh                            # 新机器一键引导, 幂等
install/macos/
  ├── brew.sh                       # 装 Homebrew + 关 analytics
  ├── packages.sh                   # brew bundle install
  └── defaults.sh                   # 写 macOS 系统偏好

home/                               # chezmoi source root (.chezmoiroot=home)
  ├── .chezmoi.toml.tmpl            # chezmoi 主配置模板 (age 加密设置)
  ├── .chezmoiignore                # 不同步的文件
  ├── .chezmoiexternal.toml         # 外部依赖 (oh-my-tmux 等)
  ├── .chezmoiscripts/macos/        # run_once_before_* / run_once_after_*
  ├── dot_config/                   # → ~/.config/
  └── private_dot_local/            # → ~/.local/  (强制 0700 权限)

tests/                              # 状态审计
  ├── audit.sh                      # runtime, 数据驱动
  ├── audit.yaml                    # 检查项声明
  └── checks.sh                     # 复杂检查的 helper 函数库

.github/workflows/
  ├── lint.yml                      # 每次 push 跑: shellcheck / fish 语法 / 模板渲染
  └── audit.yml                     # 手动 dispatch + 每周一: 全流程 apply + audit
```

---

## 新机器引导

1. 把上一台机器的 age 私钥放到 `~/.config/chezmoi/age-key.txt`（`chmod 600`）。
2. 跑引导脚本：
   ```sh
   curl -fsSL https://raw.githubusercontent.com/tokisakiyuu/dotfiles/main/setup.sh | bash
   ```
   `setup.sh` 是幂等的——已经 init 过的机器上重跑只会打印一行提示就退出。
3. `chezmoi apply` 把 dotfiles 部署到 `~`，触发 `run_once_*` 脚本装 brew、装 Brewfile、写 macOS defaults。
4. 跑 `bash tests/audit.sh` 确认状态全部落地。

---

## 日常维护

### 场景一：随便改了 `~` 下的文件，想推上去

```fish
dots
```

`dots` 一把梭：

1. `chezmoi update` 先拉远端（避免后面 re-add 覆盖刚 pull 的更新）
2. `chezmoi status` 列出有差异的文件
3. `fzf` 多选 + diff preview，挑要提交的
4. `chezmoi re-add` 把选中的反向写回 source
5. 提示输入 commit message
6. `git commit && git push`

### 场景二：新增一个文件让 chezmoi 管

```fish
chezmoi add ~/.config/newthing.conf
cd (chezmoi source-path)/..
git add -A; git commit; git push
```

### 场景三：跨机器拉别的机器的更新

```fish
chezmoi update      # 等价 chezmoi git pull + chezmoi apply
```

### 场景四：手动审计 `~` 状态

```fish
bash tests/audit.sh                       # 全部 section
bash tests/audit.sh brew defaults         # 指定 section
bash tests/audit.sh --except casks        # 反向选择
bash tests/audit.sh --list                # 看有哪些 section
```

---

## 工具命令一览

### fish 函数（chezmoi 部署后自动可用）

| 命令 | 用途 |
| --- | --- |
| `dots` | 日常一把梭：pull → 选 → re-add → commit → push |
| `dotfiles-check` | 本地 lint：shellcheck + fish -n + chezmoi diff |
| `ll` | `eza` 的别名，带图标列文件 |
| `keychain-env <KEY> [VALUE]` | 在 macOS Keychain 里读/写环境变量值 |
| `delete-upstream-gone-branchs` | 清掉 upstream 已删的本地 git 分支 |
| `scribo-db-shell <env>` | Scribo mongosh 启动器 |
| `rm` | 被故意打补丁，提示用 `mv ./x ~/.Trash` |

### chezmoi 常用

| 命令 | 用途 |
| --- | --- |
| `chezmoi update` | git pull + apply，一步同步远端 |
| `chezmoi apply` | source → target（注意默认会跑 run_once_* 脚本） |
| `chezmoi apply --exclude=scripts` | 只同步 dotfiles，不跑脚本 |
| `chezmoi re-add [path]` | 反向同步：target → source |
| `chezmoi add <path>` | 把新文件纳入管理 |
| `chezmoi diff` | source 应用到 target 会改什么 |
| `chezmoi status` | 列出有差异的文件 (git status 风格) |
| `chezmoi managed` | 列出所有受管路径 |
| `chezmoi source-path` | 打印 source root 目录 |
| `chezmoi edit <path>` | 用 $EDITOR 编辑 source 对应文件（加密文件唯一安全的编辑入口） |

### 审计

| 命令 | 用途 |
| --- | --- |
| `bash tests/audit.sh` | 跑全部 audit section |
| `bash tests/audit.sh <section>...` | 只跑指定 section |
| `bash tests/audit.sh --except <section>...` | 反向选择 |
| `bash tests/audit.sh --list` | 列出 section |

---

## chezmoi 约定速查

### Script 命名

| 前缀 | 行为 |
| --- | --- |
| `run_once_before_<name>.sh` | 在 dotfiles 同步**之前**跑一次 |
| `run_once_after_<name>.sh` | 在 dotfiles 同步**之后**跑一次 |
| `run_once_<name>.sh` | ⚠️ **不要这么写** — 文档说默认 "after"，实际是按 source 字母序混着跑，依赖 dotfile 的脚本会找不到文件。务必显式写 `after_` |

### 文件属性前缀

| 前缀 | 含义 |
| --- | --- |
| `private_` | 目录或文件 0700 权限 |
| `executable_` | 文件 0755 权限 |
| `encrypted_` | age 加密文件，source 是密文，target 是明文 |
| `create_` | 目标不存在才创建，已存在永不覆盖（适合应用自己维护的文件） |
| `symlink_` | 目标是 symlink，文件内容是 symlink 指向 |
| `dot_` | 目标名前缀 `.`（`dot_config/` → `.config/`） |

### Externals

`home/.chezmoiexternal.toml` 声明外部依赖。当前 oh-my-tmux 走 `git-repo` 类型，默认每 168h 刷一次。强制刷新：

```sh
chezmoi apply --refresh-externals
```

---

## 注意事项

1. **`dots` 内部顺序千万别反**。如果绕开 `dots` 手动操作，先 `chezmoi update` 再 `chezmoi re-add`，否则会用本机旧的 target 覆盖刚 pull 下来的 source 新版本，等于丢失另一台机器的提交。

2. **加密文件只编辑 target**。`~/.config/fish/conf.d/env.secret.fish` 直接 `nvim` 编辑，`chezmoi re-add` 会自动加密成 source 的 `.age` 文件。**不要直接编辑 source 的 `encrypted_*.age` 文件**——那是密文。

3. **`fish_variables` 用 `create_` 前缀**。fish 自己持续读写这个文件，`create_` 让 chezmoi 只在初次创建后不再覆盖，避免每次启动 fish 都产生 chezmoi diff 抖动。

4. **新增 macOS defaults**：
   - 在 `install/macos/defaults.sh` 加 `defaults write ...`
   - 在 `tests/audit.yaml` `defaults` section 加对应 `defaults read` 校验
   - 重命名 `run_once_after_99-install-defaults.sh.tmpl` 不需要，hash 变了 chezmoi 会自动重跑

5. **新增 brew 包**：直接编辑 `home/dot_config/brew/Brewfile`，下次 `chezmoi apply` 时 `packages.sh` 自动 `brew bundle install`。审计端 `check_brewfile formula/cask` 会全量验证。

6. **新增 chezmoi script**：必须显式 `run_once_before_*` 或 `run_once_after_*`（见上方注意点）。

7. **不要直接编辑 `~/.local/share/tmux/oh-my-tmux/`**。那是 external 拉的 git repo，下次 refresh 会被 reset。tmux 个人配置改 `~/.config/tmux/tmux.conf.local`。

8. **CI 不绑 PR trigger**。`lint.yml` / `audit.yml` 都只在 push to main、手动 dispatch、定时 schedule 触发，避免 fork 的 PR 拿到 `CHEZMOI_AGE_KEY` secret。

9. **CI 上不装 cask**。`audit.yml` 把 Brewfile 里 `cask` 行 grep 掉再 install（chrome、kitty 等大件下载会让 macOS runner 跑很久），并对应跑 `audit.sh --except casks` 不查 cask。本地 `chezmoi apply` 会装全。

10. **chezmoi state 是按脚本内容 hash 的**。`run_once_*` 脚本只跑一次，但你改了脚本内容 hash 就变，chezmoi 会再跑一次。所以这些脚本本身必须幂等。

---

## 故障排查

| 症状 | 可能原因 |
| --- | --- |
| `chezmoi diff` 报某个文件被修改但你没动 | 程序自己改了（如 nvim 的 lazy-lock.json），用 `dots` 选择性 re-add |
| audit `secrets decrypted` 失败 | `~/.config/chezmoi/age-key.txt` 不对或权限错（应 600） |
| audit `external` 失败 | 网络问题或 oh-my-tmux 上游变动；`chezmoi apply --refresh-externals` 重试 |
| run_once 脚本死活不跑 | chezmoi state 已记录跑过；要么改脚本内容让 hash 变，要么 `chezmoi state delete-bucket --bucket=scriptState` 重置（会让所有 once 脚本下次重跑） |
| `chezmoi apply` 提示 "config file template has changed" | 改了 `home/.chezmoi.toml.tmpl`，跑一次 `chezmoi init` 重新生成 `~/.config/chezmoi/chezmoi.toml` |
| CI smoke 挂在 `brew bundle` | 上游 brew tap 变动或 Brewfile 里某个包失踪；本地 `brew bundle check --file=~/.config/brew/Brewfile --verbose` 复现 |

---

## 加新机器之外的几个常见动作

### 重置某个 run_once 脚本

```fish
chezmoi state get --bucket=scriptState   # 列出所有跑过的 script hash
chezmoi state delete --bucket=scriptState --key=<hash>
chezmoi apply                            # 这个脚本会再跑一次
```

### 给 GitHub Actions 加/换 age key

1. 复制 `~/.config/chezmoi/age-key.txt` 内容
2. GitHub repo → Settings → Secrets and variables → Actions
3. 新建/更新 `CHEZMOI_AGE_KEY`，粘贴整段（包括 header 行 `# created: ...`）
