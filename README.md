# dotfiles

Personal dotfiles for macOS (Apple Silicon and Intel) and Arch Linux ARM, managed by [chezmoi](https://www.chezmoi.io/).

The core convention is **`~` is the source of truth, not `source/`**. Day to day you edit files under `~` (or let programs edit them for you) and then use `chezmoi re-add` to copy the changes back into source, commit, and push. This is the opposite of the more common "edit source, apply to `~`" chezmoi workflow.

---

## Repository layout

```
setup.sh                            # one-shot bootstrap for a new machine, idempotent
install/macos/
  ├── brew.sh                       # install Homebrew, turn off analytics
  ├── packages.sh                   # brew bundle install
  └── defaults.sh                   # write macOS system defaults
install/archlinux/
  ├── packages.sh                   # pacman (docker), brew bundle (Brewfile.linux), claude-code installer
  └── services.sh                   # enable docker, add user to docker group, chsh fish, kitty terminfo

home/                               # chezmoi source root (.chezmoiroot=home)
  ├── .chezmoi.toml.tmpl            # chezmoi config template (age encryption settings)
  ├── .chezmoiignore                # template; non-macOS skips kitty + the other OS's Brewfile
  ├── .chezmoiexternal.toml         # external dependencies (oh-my-tmux, ...)
  ├── .chezmoiscripts/macos/        # run_once_before_* / run_once_after_* (darwin only)
  ├── .chezmoiscripts/archlinux/    # run_once_after_* (archarm only)
  ├── dot_config/                   # -> ~/.config/
  └── private_dot_local/            # -> ~/.local/  (forced to 0700)

.github/workflows/
  ├── lint.yml                      # every push: shellcheck / fish syntax / template render
  └── smoke.yml                     # manual dispatch + weekly: chezmoi apply smoke test
```

---

## Bootstrapping a new machine

1. Drop the age private key at `~/.config/chezmoi/age-key.txt` (`chmod 600`).
2. Run the bootstrap:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/tokisakiyuu/dotfiles/main/setup.sh | bash
   ```
   `setup.sh` does three things end-to-end: fetch a chezmoi binary (uses the one on PATH if present, otherwise drops a throwaway under `~/.local/bin`), `chezmoi init` the source tree (skipped if it already exists), then **`chezmoi apply`** — which is what actually runs the per-OS install scripts:
   - **macOS** — install brew, install Brewfile, write macOS defaults.
   - **Arch Linux ARM** — `pacman -S` the docker daemon, `brew bundle` the daily-driver CLI tools from `Brewfile.linux`, install claude-code via Anthropic's native installer, enable `docker.service`, add `$USER` to the `docker` group, and `chsh` to fish.

   The throwaway chezmoi is deleted only after a package-manager copy is detected on PATH, so a partial run never leaves the host without a working chezmoi. Safe to re-run.

   On **Arch Linux ARM** make sure `bash`, `sudo`, and `curl` are present and that [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux) is already installed (the package script drives `brew bundle`); also add your user to the `wheel` group so `sudo` works.
3. On **Arch Linux ARM**: log out and back in once for the new `docker` group and the fish login shell to take effect.

---

## Day-to-day

The repo's convention is **`~` is the source of truth**, so the daily flow runs in two directions. The "pull" half is straight chezmoi-recommended commands; the "push back" half pulls without `apply` so it doesn't interrupt the collection step with per-file overwrite prompts.

### Pull remote changes (source → `~`)

```fish
chezmoi update                          # = chezmoi git pull --autostash --rebase + chezmoi apply
```

If a target file in `~` was modified since chezmoi last wrote it, `apply` prompts before overwriting — pick overwrite / skip / diff / merge / quit. To preview first instead of trusting the prompt:

```fish
chezmoi git pull -- --autostash --rebase
chezmoi diff
chezmoi apply
```

### Push your `~` changes back (`~` → source)

```fish
chezmoi git pull -- --autostash --rebase   # update source without writing to ~
chezmoi status                              # list paths that differ
chezmoi re-add <path>...                    # copy ~ contents back into source
cd (chezmoi source-path)/..
git add -A
git commit
git push
```

Don't reach for `chezmoi update` here. `apply` would prompt once per modified file before letting `re-add` run, and even after answering "keep" the source still doesn't reflect `~` — `re-add` is what actually closes the loop, so the prompt detour is just noise. Pulling without applying skips it.

For a real conflict (you and another machine edited the same file) use `chezmoi merge <path>` — three-way merge between source, target, and destination states.

### Start managing a new file

```fish
chezmoi add ~/.config/newthing.conf
cd (chezmoi source-path)/..
git add -A; git commit; git push
```

---

## Commands

### fish functions (auto-loaded after chezmoi apply)

| Command | What it does |
| --- | --- |
| `dotfiles-check` | Local lint: shellcheck + `fish -n` + `chezmoi diff` |
| `brewfile-sync` | `brew bundle dump` into `~/.config/brew/Brewfile`; run after `brew install`/`uninstall` |
| `ll` | `eza` alias with icons and sorting |
| `keychain-env <KEY> [VALUE]` | Read or write an env var into the macOS Keychain |
| `delete-upstream-gone-branchs` | Drop local git branches whose upstream is gone |
| `scribo-db-shell <env>` | Scribo `mongosh` launcher |
| `rm` | Wrapped to refuse deletion of paths in two lists at the top of `rm.fish` (`protected_paths` for exact matches, `protected_paths_recursive` for directories whose subtree is off-limits); other rm calls pass through to `command rm` |

### chezmoi cheatsheet

| Command | What it does |
| --- | --- |
| `chezmoi update` | `git pull --autostash --rebase` + `chezmoi apply`; one-step sync from remote |
| `chezmoi git pull -- --autostash --rebase` | pull source without applying — use before `re-add` |
| `chezmoi apply` | source → target (also runs `run_once_*` by default; prompts on locally-modified targets) |
| `chezmoi apply --exclude=scripts` | sync dotfiles only, skip scripts |
| `chezmoi re-add [path]` | reverse sync: target → source |
| `chezmoi add <path>` | start managing a new file |
| `chezmoi diff` | preview what source → target would change |
| `chezmoi status` | git-status-style listing of differing paths |
| `chezmoi merge <path>` | three-way merge (source / target / destination) for resolving conflicts |
| `chezmoi managed` | list every path chezmoi manages |
| `chezmoi source-path` | print the source root directory |
| `chezmoi edit <path>` | open the source file in `$EDITOR` (only safe way to edit encrypted files) |

---

## chezmoi conventions

### Script names

| Prefix | When it runs |
| --- | --- |
| `run_once_before_<name>.sh` | once, **before** dotfiles are synced |
| `run_once_after_<name>.sh` | once, **after** dotfiles are synced |
| `run_once_<name>.sh` | ⚠️ **don't use this form** — the docs say it defaults to "after", but the actual behavior is alphabetical-order interleaving with the source tree, which means scripts that depend on dotfiles can run too early. Always write the explicit `after_`. |

### File attribute prefixes

| Prefix | Meaning |
| --- | --- |
| `private_` | directory or file with 0700 permissions |
| `executable_` | file with 0755 permissions |
| `encrypted_` | age-encrypted; source is ciphertext, target is plaintext |
| `create_` | created only if the target doesn't exist; never overwritten (good for files that the app maintains itself) |
| `symlink_` | target is a symlink; file content is the symlink destination |
| `dot_` | target name starts with `.` (`dot_config/` → `.config/`) |

### Externals

`home/.chezmoiexternal.toml` declares external dependencies. oh-my-tmux is a `git-repo` external, refreshed once a week (`refreshPeriod = "168h"`). Force a refresh with:

```sh
chezmoi apply --refresh-externals
```

---

## Things to watch out for

1. **Don't reverse the pull → `re-add` order.** Always run `chezmoi git pull -- --autostash --rebase` (or `chezmoi update`) before `chezmoi re-add`. Unlike `apply` (which prompts on locally-modified targets), `re-add` does *not* prompt — running it first silently overwrites the source with your stale local target, throwing away whatever the other machine just pushed.

2. **Edit encrypted files at the target, not the source.** Open `~/.config/fish/conf.d/env.secret.fish` in `nvim` as plaintext; `chezmoi re-add` will encrypt it back into the source `.age` file. **Never edit the `encrypted_*.age` files in source** — that's ciphertext.

3. **`fish_variables` uses `create_`.** fish constantly rewrites this file at runtime. The `create_` prefix tells chezmoi to seed it once and leave it alone afterwards, so you don't get a chezmoi diff every time you start a shell.

4. **Adding a new macOS default**:
   - Add a `defaults write ...` line in `install/macos/defaults.sh`
   - No renaming needed: changing the script's hash makes chezmoi re-run it next apply

5. **Adding a brew package**: edit `home/dot_config/brew/Brewfile` on macOS, or `home/dot_config/brew/Brewfile.linux` on Arch (formulae only — Homebrew has no cask support on Linux). Next `chezmoi apply` will let `packages.sh` install it via `brew bundle install`. Each OS only sees its own Brewfile; `.chezmoiignore` hides the other one.

6. **Adding a new chezmoi script**: always pick `run_once_before_*` or `run_once_after_*` explicitly. See the script naming note above.

7. **Don't edit `~/.local/share/tmux/oh-my-tmux/` directly.** That's the external git checkout; it gets reset on refresh. Your tmux tweaks belong in `~/.config/tmux/tmux.conf.local`.

8. **CI is not triggered by PRs.** `lint.yml` and `smoke.yml` only run on push-to-main, manual dispatch, and the weekly schedule. This is deliberate: it keeps the `CHEZMOI_AGE_KEY` secret out of forked PR contexts.

9. **CI is a smoke test only.** `smoke.yml` runs `chezmoi init` + `chezmoi apply --exclude=scripts` and passes if apply exits cleanly. It skips `run_once_*` scripts (brew casks are gigabytes on GitHub runners). A local `chezmoi apply` still installs everything.

10. **chezmoi keeps state by script hash.** A `run_once_*` script only runs the first time, but if you change its contents the hash changes and it runs again. The scripts therefore have to be idempotent — and they are: `install_homebrew` short-circuits when brew is present, `brew bundle install --no-upgrade` is a no-op when nothing's missing, `defaults write` is idempotent by definition.

11. **Arch Linux ARM specifics.** The Arch host is glibc + [Homebrew on Linux](https://docs.brew.sh/Homebrew-on-Linux), so it mirrors macOS closely: CLI tools come from `brew bundle` (`Brewfile.linux`), and only the docker daemon (which brew can't manage on Linux) is installed via `pacman` — edit the inline `PACMAN_PACKAGES=(...)` list in `install/archlinux/packages.sh` for system-level packages. claude-code can't come from brew (its formula is a macOS-only cask), so `install_claude_code` runs Anthropic's native installer instead. Because it's glibc, Mason installs its prebuilt arm64 binaries normally — no musl workarounds in `nvim/lua/plugins/lsp.lua` (only `rust_analyzer` is gated to macOS, since rust dev only happens there). `keychain-env` is macOS-only (it uses `/usr/bin/security`); elsewhere it returns an error rather than misbehaving. The Rust toolchain block in `config.fish` is glob-driven (`stable-*/bin`) and silently no-ops when `~/.rustup` doesn't exist — Arch gets no rust, no PATH pollution.

12. **`rm` is a fish-only shield.** The wrapper at `home/dot_config/fish/functions/rm.fish` refuses to delete paths listed in two lists at the top of the file: `protected_paths` (exact files or directories) and `protected_paths_recursive` (directory subtrees, the root and everything beneath). Edit those lists in source, then commit and push from `(chezmoi source-path)/..`. Anything else passes through to the real `rm`. This only catches interactive fish shells — `command rm`, bash/zsh, scripts, cron jobs, and other non-fish callers bypass it.

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `chezmoi diff` shows changes to a file you didn't touch | A program edited it (e.g. nvim's `lazy-lock.json`). Re-add it to keep the change, or `chezmoi apply` to discard it. |
| secrets fail to decrypt | `~/.config/chezmoi/age-key.txt` is missing, wrong, or not `chmod 600` |
| an external (e.g. oh-my-tmux) looks stale or broken | network issue or upstream change; retry with `chezmoi apply --refresh-externals` |
| A `run_once` script won't run | chezmoi state already recorded it ran. Either change the script's contents (changes its hash) or `chezmoi state delete-bucket --bucket=scriptState` to reset all `once` scripts. |
| `chezmoi apply` says "config file template has changed" | You edited `home/.chezmoi.toml.tmpl`. Run `chezmoi init` once to regenerate `~/.config/chezmoi/chezmoi.toml`. |
| CI smoke test fails at `chezmoi apply` | Template render error, secret decryption failure, or an external (e.g. oh-my-tmux) moved. Reproduce locally with `chezmoi apply --dry-run --verbose`. |

---

## Common one-off operations

### Force a specific `run_once` script to re-run

```fish
chezmoi state get --bucket=scriptState              # list recorded scripts
chezmoi state delete --bucket=scriptState --key=<hash>
chezmoi apply                                       # the script will run again
```

### Rotate the GitHub Actions age key

1. Copy the contents of `~/.config/chezmoi/age-key.txt` (including the `# created: ...` header line).
2. GitHub repo → Settings → Secrets and variables → Actions.
3. Create or update `CHEZMOI_AGE_KEY` with the full contents.
