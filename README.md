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
cd kitty
bash install
```

对于那些我没写`install`脚本的package，只需要简单地执行

```bash
stow .
```

## Notes

- [Managing dotfiles using GNU Stow on macOS](https://dev.to/hitblast/managing-configuration-using-gnu-stow-on-macos-5ff6)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [stow: .stow-local-ignore file](https://www.gnu.org/software/stow/manual/html_node/Types-And-Syntax-Of-Ignore-Lists.html)
- [stow: .stowrc file](https://www.gnu.org/software/stow/manual/html_node/Resource-Files.html)
- [Brew Bundle Brewfile Tips](https://gist.github.com/ChristopherA/a579274536aab36ea9966f301ff14f3f)
