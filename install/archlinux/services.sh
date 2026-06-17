#!/usr/bin/env bash

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
  set -x
fi

# Post-package setup: enable docker, add user to docker group, switch login
# shell to fish, alias the kitty terminfo entry. Idempotent — re-running is a
# no-op once everything is in place.

function load_brew_env() {
  # This script runs under chezmoi's non-interactive bash, which has no
  # linuxbrew on PATH — so brew-installed tools (fish) are invisible without
  # this. packages.sh does the same before its brew commands.
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

function enable_docker() {
  # docker.service is TriggeredBy docker.socket; enabling both makes startup
  # explicit and survives upstream changes to the trigger relationship.
  sudo systemctl enable --now docker.socket docker.service
}

function add_user_to_docker_group() {
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    return 0
  fi
  # groupadd/usermod ship with util-linux/shadow on Arch (Alpine's
  # addgroup/adduser don't exist here). The docker package already creates the
  # group, so groupadd is usually a no-op guarded by getent.
  if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker
  fi
  sudo usermod -aG docker "$USER"
  echo "Note: log out and back in for the docker group membership to take effect." >&2
}

function set_default_shell_to_fish() {
  local fish_bin
  fish_bin=$(command -v fish || true)
  if [[ -z "$fish_bin" ]]; then
    echo "fish not found on PATH; packages.sh should have installed it via brew." >&2
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

function ensure_zram_swap() {
  # Compressed RAM-backed swap so the phone's limited memory doesn't OOM under
  # neovim+LSP/docker/brew builds. zram-generator (installed by packages.sh)
  # turns this declarative config into a swap device via a systemd generator;
  # the kernel ships zram builtin with zstd as its default backend. Sized at
  # half of RAM, capped at 4G.
  local target=/etc/systemd/zram-generator.conf
  local desired
  desired=$(cat <<'CONF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
CONF
)
  # Skip rewrite + reload when the file is already exactly right, so repeat
  # runs don't tear the swap device down and back up.
  if [[ -r "$target" ]] && printf '%s\n' "$desired" | diff -q - "$target" >/dev/null 2>&1; then
    return 0
  fi
  printf '%s\n' "$desired" | sudo tee "$target" >/dev/null
  sudo chmod 0644 "$target"
  # zram-generator is a systemd generator: daemon-reload re-runs it to (re)create
  # the units. Restart the .swap unit specifically — it pulls in the setup
  # service to size the device and then actually swapon's it. Restarting the
  # setup service alone leaves the device created but swap off.
  sudo systemctl daemon-reload
  sudo systemctl restart dev-zram0.swap
}

function ensure_flash_swapfile() {
  # Low-priority flash-backed swap as an OOM safety net *below* zram (pri 100).
  # zram lives in RAM and this kernel can't spill incompressible pages anywhere
  # (CONFIG_ZRAM_WRITEBACK is off), so this file is the slow last resort before
  # the OOM killer. Kept small on purpose — a cushion, not primary swap; flash
  # swap is slow and thrashes.
  local file=/swapfile
  local size_mb=2048
  local prio=10
  if [[ ! -f "$file" ]]; then
    # dd, not fallocate: swapon rejects files with holes, and the rootfs is a
    # loop-backed ext4 image where fully-written blocks are the safe bet.
    sudo dd if=/dev/zero of="$file" bs=1M count="$size_mb" status=none
    sudo chmod 600 "$file"
    sudo mkswap "$file" >/dev/null
  fi
  # Persist across boots via fstab; append only when no entry references it.
  if ! grep -qE "^${file}[[:space:]]" /etc/fstab; then
    printf '%s none swap defaults,pri=%s 0 0\n' "$file" "$prio" | sudo tee -a /etc/fstab >/dev/null
  fi
  # Activate now if it isn't already swapped on.
  if ! swapon --show=NAME --noheadings | grep -qxF "$file"; then
    sudo swapon --priority "$prio" "$file"
  fi
}

function main() {
  load_brew_env
  enable_docker
  add_user_to_docker_group
  set_default_shell_to_fish
  alias_kitty_terminfo
  ensure_zram_swap
  ensure_flash_swapfile
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
