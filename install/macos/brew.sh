#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

function is_homebrew_installed() {
  [[ -x /opt/homebrew/bin/brew ]] || [[ -x /usr/local/bin/brew ]] || command -v brew &>/dev/null
}

function load_brew_env() {
  # Required after a fresh install: the installer updates ~/.zprofile but the
  # current shell still has the pre-install PATH.
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

function install_homebrew() {
  if ! is_homebrew_installed; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

function opt_out_of_analytics() {
  brew analytics off
}

function main() {
  install_homebrew
  load_brew_env
  opt_out_of_analytics
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
