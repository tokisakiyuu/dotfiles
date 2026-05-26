#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

function load_brew_env() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

function require_brew() {
  if ! command -v brew &>/dev/null; then
    echo "brew not found; run install/macos/brew.sh first." >&2
    exit 1
  fi
}

function install_packages() {
  # --no-upgrade keeps the run idempotent: already-installed formulae are
  # not touched, so re-running this script is cheap and safe.
  brew bundle install --no-upgrade --file="${HOME}/.config/brew/Brewfile"
}

function main() {
  load_brew_env
  require_brew
  install_packages
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
