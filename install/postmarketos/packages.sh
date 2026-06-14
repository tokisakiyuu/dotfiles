#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

# Minimum set of tools to bring this host up to a usable shell.
# Not aiming for full parity with the macOS Brewfile — just the daily-driver list.
readonly PACKAGES=(
  bash
  curl
  chezmoi
  fish
  starship
  git
  tmux
  neovim
  # build-base ships gcc/g++/make/musl-dev — required for nvim-treesitter
  # to compile parsers on first use.
  build-base
  # tree-sitter CLI — nvim-treesitter uses it to generate / install parsers.
  tree-sitter-cli
  # nodejs + npm — Mason installs npm-based LSPs (eslint, vtsls,
  # tailwindcss, graphql, jsonls, prismals) via the system npm.
  nodejs
  npm
  # Mason has no musl-linux release for these; install the distro packages
  # instead and nvim-lspconfig/conform pick them up from PATH.
  lua-language-server
  stylua
  # fd — Snacks.picker.explorer + LazyVim file pickers.
  fd
  # Mason archive deps. busybox provides gzip as an applet but Mason looks
  # for the GNU binary path explicitly; ditto unzip.
  unzip
  gzip
  ripgrep
  fzf
  zoxide
  eza
  lazygit
  docker
  docker-cli-compose
  shadow
  # Claude Code, served from the Anthropic-signed apk repo configured below.
  claude-code
)

# Anthropic-signed apk repository URL and key (stable channel).
# Docs: https://code.claude.com/docs/en/setup#install-with-linux-package-managers
readonly CLAUDE_CODE_REPO="https://downloads.claude.ai/claude-code/apk/stable"
readonly CLAUDE_CODE_KEY_URL="https://downloads.claude.ai/keys/claude-code.rsa.pub"
readonly CLAUDE_CODE_KEY_PATH="/etc/apk/keys/claude-code.rsa.pub"
readonly CLAUDE_CODE_KEY_SHA256="395759c1f7449ef4cdef305a42e820f3c766d6090d142634ebdb049f113168b6"

function require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found; install it first (apk add sudo) and add yourself to the wheel group." >&2
    exit 1
  fi
}

function setup_claude_code_repo() {
  # Fetch the signing key if missing and verify the published sha256 before
  # trusting it. Re-downloading every run would still be safe (sha256 catches
  # tampering) but skipping is faster and avoids needless network use.
  if [[ ! -f "$CLAUDE_CODE_KEY_PATH" ]]; then
    sudo curl -fsSL "$CLAUDE_CODE_KEY_URL" -o "$CLAUDE_CODE_KEY_PATH"
  fi
  local actual
  actual=$(sha256sum "$CLAUDE_CODE_KEY_PATH" | awk '{print $1}')
  if [[ "$actual" != "$CLAUDE_CODE_KEY_SHA256" ]]; then
    echo "claude-code signing key sha256 mismatch (got $actual, expected $CLAUDE_CODE_KEY_SHA256)" >&2
    sudo rm -f "$CLAUDE_CODE_KEY_PATH"
    exit 1
  fi
  # Append the repository line only when missing — prevents duplicates on re-runs.
  if ! grep -qF "$CLAUDE_CODE_REPO" /etc/apk/repositories; then
    echo "$CLAUDE_CODE_REPO" | sudo tee -a /etc/apk/repositories >/dev/null
  fi
}

function install_packages() {
  # `apk add` is idempotent for already-installed packages, so this is safe to re-run.
  sudo apk update
  sudo apk add --no-progress "${PACKAGES[@]}"
}

function main() {
  require_sudo
  setup_claude_code_repo
  install_packages
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
