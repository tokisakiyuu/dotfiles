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
)

function require_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found; install it first (apk add sudo) and add yourself to the wheel group." >&2
    exit 1
  fi
}

function install_packages() {
  # `apk add` is idempotent for already-installed packages, so this is safe to re-run.
  sudo apk update
  sudo apk add --no-progress "${PACKAGES[@]}"
}

function main() {
  require_sudo
  install_packages
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
