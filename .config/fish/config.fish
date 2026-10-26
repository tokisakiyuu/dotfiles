if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Homebrew (Apple Silicon and Intel Macs)
if test -x /opt/homebrew/bin/brew
    /opt/homebrew/bin/brew shellenv | source
else if test -x /usr/local/bin/brew
    /usr/local/bin/brew shellenv | source
end

# Native CLI installers use this directory.
fish_add_path -g $HOME/.local/bin

# Terminal shell prompt (installed by Homebrew)
# https://starship.rs/
starship init fish | source
# Suppress all startship warnings
set -gx STARSHIP_LOG error

# Auto set http/https proxy. `nc -z` is much cheaper than `lsof` on macOS,
# and this check runs on every shell startup. Guarded on nc existing so hosts
# without netcat do not error out on startup.
if command -q nc; and nc -z 127.0.0.1 7890 2>/dev/null
    set -gx http_proxy http://127.0.0.1:7890
    set -gx https_proxy http://127.0.0.1:7890
    set -gx all_proxy socks5://127.0.0.1:7890
end

set -gx SHELL (command -v fish)

# Suppress fish default greeting
set -g fish_greeting ''

# pnpm home
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path -g "$PNPM_HOME"

# node@24 is keg-only, so Homebrew never symlinks it — adding its bin by hand is
# what keeps us pinned to 24 instead of drifting onto the latest `node`. Probing
# a fixed list beats `brew --prefix` here: this runs on every shell startup.
for p in /opt/homebrew/opt/node@24/bin /usr/local/opt/node@24/bin
    test -d $p; and fish_add_path -g $p
end

# Rust toolchains installed on this Mac.
for tc in $HOME/.rustup/toolchains/stable-*/bin
    test -d $tc; and fish_add_path -g $tc
end
test -d $HOME/.cargo/bin; and fish_add_path -g $HOME/.cargo/bin

# Terminal programs UI language
set -gx LANG "en_US.UTF-8"

# avante.nvim API Key
# set -gx OPENAI_API_KEY (keychain-env KIMI_API_KEY)

# zoxide, z command (installed by Homebrew)
set -gx _ZO_DATA_DIR "$HOME/.local/share/z"
zoxide init fish | source
# Alt+Z: pick a dir interactively and insert the path at the cursor
bind \ez zi-insert

# Command Editor command
set -gx EDITOR (command -v nvim)

# Apply machine-specific values after the shared configuration.
source "$HOME/.config/dotfiles/machine.fish"
