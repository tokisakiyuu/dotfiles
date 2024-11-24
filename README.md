# TokisakiYuu's dotfiles

## Requirements

- `git`: 用于拉取这个仓库
- [`stow`](https://www.gnu.org/software/stow/): 管理点文件的符号链接

通常这两个工具都可以用macos自带的`brew`安装。

## Reproduce dotfiles on new machine

1. 拉取仓库

```bash
git clone https://github.com/tokisakiyuu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

2. 按需安装package

例如，需要在此机器上安装kitty

```bash
stow kitty
```

## Adding new package

假设，新的package名为`face`，它的配置文件集中在`~/.config/x/y/face`。

1. 在`~/.dotfiles/face`目录下创建相同的目录结构`.config/x/y`

2. 将配置文件移动到对应目录下（移动前记得拷贝备份）

```bash
mv ~/.config/x/y/face ~/.dotfiles/face/.config/x/y/
```

3. 创建链接

```bash
cd ~/.dotfiles
stow face
```

## Stow Guide

- 创建链接

```bash
stow <package>
```

它会按照package中的目录结构，在当前目录的上一级，也就是`~`（当前目录是`~/.dotfiles`的话）下，创建相应的符号链接。

- 删除链接

```bash
stow -D <package>
```

与上面完全相反的操作，也就是清理符号链接。

- 应用本地文件

```bash
stow --adopt <package>
```

将原本在机器上的文件内容，写进package对应文件中（如果有的话），这意味着package中对应的文件的内容会被**覆盖**，这些被覆盖的内容一般是来自别的机器的配置，所以要配合git来酌情处理合并或丢弃。

- 不想让package中的某些文件被生成链接

需要在package的根目录创建`.stow-local-ignore`文件，将不想链接的文件追加进去，支持正则匹配，详细见下方。有一点需要注意的是，忽略的文件或目录也只能是存在于package的根目录。例如，上例中的`face`我配置了忽略`auth.cert`文件，`face/auth.cert`可以被忽略，但是`face/x/y/auth.cert`不会被忽略。

## Notes

- [Managing dotfiles using GNU Stow on macOS](https://dev.to/hitblast/managing-configuration-using-gnu-stow-on-macos-5ff6)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [stow: .stow-local-ignore file](https://www.gnu.org/software/stow/manual/html_node/Types-And-Syntax-Of-Ignore-Lists.html)
- [stow: .stowrc file](https://www.gnu.org/software/stow/manual/html_node/Resource-Files.html)
