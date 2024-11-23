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

## Adding new file to package

有时，一些程序所需的配置文件会增加，所以我需要将新增的文件手动纳入package的管理。例如，我在`~/.config/fish/functions/`中新增了一个`foo.fish`，我需要做的是

1. 复制`foo.fish`到package中相应的位置

```bash
cp ~/.config/fish/functions/foo.fish ~/.dotfiles/fish/functions/
```

2. 创建符号链接

```bash
cd ~/.dotfiles/fish
stow --adopt .
```

这样就可以了。

有种特殊情况，就是新增了大量需要纳入package管理的配置文件，且它们还有可能分布在不同的文件夹中，需要找到这些配置的共同父文件夹，假设是`~/.config/fish`然后递归复制

```bash
cp -r -i ~/.config/fish/* ~/.dotfiles/fish/
```

这样能够保持正确的文件结构复制进package里面，但是应该会看到一大堆这样的提示

```
cp: xxx/a.txt and a.txt are identical (not copied).
```

这是因为`cp`命令并不会过滤符号链接，这样的操作相当于是把一些符号链接也尝试复制到它们的源路径了。这只是提示并跳过，过程应该不会出错。

## Adding new package

这个过程和上面类似

1. 将已经存在的配置文件夹整个复制进来

```bash
cp ~/.config/xxx ~/.dotfiles/xxx/
```

2. 创建stow配置文件

```bash
cd ~/.dotfiles/xxx
echo "--target=$HOME/.config/xxx" > .stowrc
echo -e ".stowrc\nREADME\\.md\ninstall" > .stow-local-ignore
```

3. 然后创建符号链接

```bash
stow --adopt .
```

## Notes

- [Managing dotfiles using GNU Stow on macOS](https://dev.to/hitblast/managing-configuration-using-gnu-stow-on-macos-5ff6)
- [GNU Stow](https://www.gnu.org/software/stow/)
- [stow: .stow-local-ignore file](https://www.gnu.org/software/stow/manual/html_node/Types-And-Syntax-Of-Ignore-Lists.html)
- [stow: .stowrc file](https://www.gnu.org/software/stow/manual/html_node/Resource-Files.html)
