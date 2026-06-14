#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

# Post-package setup: enable docker, add user to docker group, switch login shell to fish.
# Idempotent — re-running is a no-op once everything is in place.

function enable_docker() {
  # docker.service is TriggeredBy docker.socket; enabling both makes startup explicit
  # and survives upstream changes to the trigger relationship.
  sudo systemctl enable --now docker.socket docker.service
}

function add_user_to_docker_group() {
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    return 0
  fi
  # `addgroup` exists on Alpine/pmOS via the `shadow` package and busybox.
  # `getent group docker` works once the docker package has created the group.
  if ! getent group docker >/dev/null 2>&1; then
    sudo addgroup docker
  fi
  sudo adduser "$USER" docker
  echo "Note: log out and back in for the docker group membership to take effect." >&2
}

function set_default_shell_to_fish() {
  local fish_bin
  fish_bin=$(command -v fish || true)
  if [[ -z "$fish_bin" ]]; then
    echo "fish not found on PATH; packages.sh should have installed it." >&2
    return 1
  fi
  # Register fish in /etc/shells if missing so chsh accepts it.
  if ! grep -qxF "$fish_bin" /etc/shells; then
    echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null
  fi
  # Skip chsh if the user's login shell is already fish.
  local current
  current=$(getent passwd "$USER" | awk -F: '{print $7}')
  if [[ "$current" == "$fish_bin" ]]; then
    return 0
  fi
  sudo chsh -s "$fish_bin" "$USER"
}

function alias_kitty_terminfo() {
  # ncurses upstream ships the entry as `kitty` but Kitty itself sends
  # TERM=xterm-kitty, so a fresh SSH from a Kitty client fails with
  # "missing or unsuitable terminal" until we alias. Skip if either the
  # system already has xterm-kitty or the source entry is missing.
  if [[ -e /usr/share/terminfo/x/xterm-kitty ]] \
     || [[ -e "$HOME/.terminfo/x/xterm-kitty" ]] \
     || [[ ! -e /usr/share/terminfo/k/kitty ]]; then
    return 0
  fi
  mkdir -p "$HOME/.terminfo/x"
  ln -sf /usr/share/terminfo/k/kitty "$HOME/.terminfo/x/xterm-kitty"
}

function main() {
  enable_docker
  add_user_to_docker_group
  set_default_shell_to_fish
  alias_kitty_terminfo
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
