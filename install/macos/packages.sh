#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

function install_packages() {
  brew bundle install --no-upgrade --file=$HOME/.config/brew/Brewfile
}

function main() {
  install_packages
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
