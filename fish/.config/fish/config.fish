if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Homebrew
/opt/homebrew/bin/brew shellenv | source

# Terminal shell prompt (installed by Homebrew)
# https://starship.rs/
starship init fish | source
# Suppress all startship warnings
set -gx STARSHIP_LOG error

# Auto set http/https proxy
if test -n (lsof -Pi :7890 -sTCP:LISTEN | string collect)
    set -gx http_proxy http://127.0.0.1:7890
    set -gx https_proxy http://127.0.0.1:7890
    set -gx all_proxy socks5://127.0.0.1:7890
end

set -gx SHELL /opt/homebrew/bin/fish

# XDG basedir
# https://wiki.archlinux.org/title/XDG_Base_Directory

# Suppress fish default greeting
set -g fish_greeting ''

# pnpm home
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
set -gx PATH "$PNPM_HOME:$PATH"

# Rust Toolchains
set -gx PATH "$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH"

# Terminal programs UI language
set -gx LANG "en_US.UTF-8"

# avante.nvim API Key
# set -gx OPENAI_API_KEY (keychain-env KIMI_API_KEY)

# zoxide, z command (installed by Homebrew)
set -gx _ZO_DATA_DIR "$HOME/.local/share/z"
zoxide init fish | source

# Command Editor command
set -gx EDITOR /opt/homebrew/bin/nvim
