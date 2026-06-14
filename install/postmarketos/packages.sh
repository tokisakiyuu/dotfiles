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
  fish
  starship
  git
  tmux
  neovim
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
