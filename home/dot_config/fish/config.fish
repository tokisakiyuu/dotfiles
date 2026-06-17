if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Homebrew (Apple Silicon, Intel mac, Linux)
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv | source
else if test -x /usr/local/bin/brew
    /usr/local/bin/brew shellenv | source
else if test -x /home/linuxbrew/.linuxbrew/bin/brew
    /home/linuxbrew/.linuxbrew/bin/brew shellenv | source
end

# claude-code's native installer drops its binary here; fish doesn't add it by
# default. Harmless on macOS where the path may not exist.
fish_add_path -g $HOME/.local/bin

# Terminal shell prompt (installed by Homebrew)
# https://starship.rs/
starship init fish | source
# Suppress all startship warnings
set -gx STARSHIP_LOG error

# Auto set http/https proxy. `nc -z` is much cheaper than `lsof` on macOS,
# and this check runs on every shell startup. Guarded on nc existing so hosts
# without netcat (e.g. a bare Arch install) don't error out on every startup.
if command -q nc; and nc -z 127.0.0.1 7890 2>/dev/null
    set -gx http_proxy http://127.0.0.1:7890
    set -gx https_proxy http://127.0.0.1:7890
    set -gx all_proxy socks5://127.0.0.1:7890
end

set -gx SHELL (command -v fish)

# XDG basedir
# https://wiki.archlinux.org/title/XDG_Base_Directory

# Suppress fish default greeting
set -g fish_greeting ''

# pnpm home
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
set -gx PATH "$PNPM_HOME:$PATH"

# Rust Toolchains — discover host triple at runtime so the same line works on
# macOS (stable-aarch64-apple-darwin), Linux/musl, Linux/gnu, etc.
for tc in $HOME/.rustup/toolchains/stable-*/bin
    test -d $tc; and set -gx PATH $tc $PATH
end
test -d $HOME/.cargo/bin; and set -gx PATH $HOME/.cargo/bin $PATH

# Terminal programs UI language
set -gx LANG "en_US.UTF-8"

# avante.nvim API Key
# set -gx OPENAI_API_KEY (keychain-env KIMI_API_KEY)

# zoxide, z command (installed by Homebrew)
set -gx _ZO_DATA_DIR "$HOME/.local/share/z"
zoxide init fish | source

# Command Editor command
set -gx EDITOR (command -v nvim)
