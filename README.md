# dotfiles

Personal dotfiles for macOS (Apple Silicon and Intel), managed by [chezmoi](https://www.chezmoi.io/).

The core convention is **`~` is the source of truth, not `source/`**. Day to day you edit files under `~` (or let programs edit them for you) and then use `chezmoi re-add` to copy the changes back into source, commit, and push. This is the opposite of the more common "edit source, apply to `~`" chezmoi workflow.

---

## Repository layout

```
setup.sh                            # one-shot bootstrap for a new machine, idempotent
install/macos/
  ├── brew.sh                       # install Homebrew, turn off analytics
  ├── packages.sh                   # brew bundle install
  └── defaults.sh                   # write macOS system defaults

home/                               # chezmoi source root (.chezmoiroot=home)
  ├── .chezmoi.toml.tmpl            # chezmoi config template (age encryption settings)
  ├── .chezmoiignore                # paths chezmoi shouldn't manage
  ├── .chezmoiexternal.toml         # external dependencies (oh-my-tmux, ...)
  ├── .chezmoiscripts/macos/        # run_once_before_* / run_once_after_*
  ├── dot_config/                   # -> ~/.config/
  └── private_dot_local/            # -> ~/.local/  (forced to 0700)

tests/                              # post-apply state audit
  ├── audit.sh                      # runtime, data-driven
  ├── audit.yaml                    # check declarations
  └── checks.sh                     # helper functions for complex checks

.github/workflows/
  ├── lint.yml                      # every push: shellcheck / fish syntax / template render
  └── audit.yml                     # manual dispatch + weekly: full apply + audit
```

---

## Bootstrapping a new machine

1. Drop the age private key at `~/.config/chezmoi/age-key.txt` (`chmod 600`).
2. Run the bootstrap:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/tokisakiyuu/dotfiles/main/setup.sh | bash
   ```
   `setup.sh` is idempotent — re-running on a machine that's already initialized just prints a notice and exits.
3. `chezmoi apply` to deploy dotfiles to `~` and run the `run_once_*` scripts (install brew, install Brewfile, write macOS defaults).
4. `bash tests/audit.sh` to confirm everything landed.

---

## Day-to-day

### You changed something under `~` and want to push it

```fish
dots
```

`dots` does the whole loop:

1. `chezmoi update` — pull and apply remote changes first (otherwise re-add could overwrite them with your stale local target)
2. `chezmoi status` — list paths that differ
3. `fzf` multi-select with diff preview — pick what to keep
4. `chezmoi re-add` — copy selected target files back into source
5. Prompt for a commit message
6. `git commit && git push`

### You want chezmoi to start managing a new file

```fish
chezmoi add ~/.config/newthing.conf
cd (chezmoi source-path)/..
git add -A; git commit; git push
```

### Sync changes from another machine

```fish
chezmoi update      # equivalent to chezmoi git pull + chezmoi apply
```

### Manually audit `~`

```fish
bash tests/audit.sh                       # all sections
bash tests/audit.sh brew defaults         # only these sections
bash tests/audit.sh --except casks        # everything except this
bash tests/audit.sh --list                # show available sections
```

---

## Commands

### fish functions (auto-loaded after chezmoi apply)

| Command | What it does |
| --- | --- |
| `dots` | Daily loop: pull → pick → re-add → commit → push |
| `dotfiles-check` | Local lint: shellcheck + `fish -n` + `chezmoi diff` |
| `brewfile-sync` | `brew bundle dump` into `~/.config/brew/Brewfile`; run after `brew install`/`uninstall` |
| `ll` | `eza` alias with icons and sorting |
| `keychain-env <KEY> [VALUE]` | Read or write an env var into the macOS Keychain |
| `delete-upstream-gone-branchs` | Drop local git branches whose upstream is gone |
| `scribo-db-shell <env>` | Scribo `mongosh` launcher |
| `rm` | Wrapped to refuse deletion of paths in three lists at the top of `rm.fish` (exact files, dir entries, recursive roots); other rm calls pass through to `command rm` |

### chezmoi cheatsheet

| Command | What it does |
| --- | --- |
| `chezmoi update` | git pull + apply, one-step sync from remote |
| `chezmoi apply` | source → target (note: also runs `run_once_*` by default) |
| `chezmoi apply --exclude=scripts` | sync dotfiles only, skip scripts |
| `chezmoi re-add [path]` | reverse sync: target → source |
| `chezmoi add <path>` | start managing a new file |
| `chezmoi diff` | preview what source → target would change |
| `chezmoi status` | git-status-style listing of differing paths |
| `chezmoi managed` | list every path chezmoi manages |
| `chezmoi source-path` | print the source root directory |
| `chezmoi edit <path>` | open the source file in `$EDITOR` (only safe way to edit encrypted files) |

### audit

| Command | What it does |
| --- | --- |
| `bash tests/audit.sh` | run every audit section |
| `bash tests/audit.sh <section>...` | run only the listed sections |
| `bash tests/audit.sh --except <section>...` | run every section but the listed ones |
| `bash tests/audit.sh --list` | print available sections |

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

1. **Don't reverse the `update` → `re-add` order.** `dots` handles this automatically, but if you do it by hand, run `chezmoi update` first. Doing `re-add` first overwrites the source with your local stale target, which silently throws away whatever the other machine just pushed.

2. **Edit encrypted files at the target, not the source.** Open `~/.config/fish/conf.d/env.secret.fish` in `nvim` as plaintext; `chezmoi re-add` will encrypt it back into the source `.age` file. **Never edit the `encrypted_*.age` files in source** — that's ciphertext.

3. **`fish_variables` uses `create_`.** fish constantly rewrites this file at runtime. The `create_` prefix tells chezmoi to seed it once and leave it alone afterwards, so you don't get a chezmoi diff every time you start a shell.

4. **Adding a new macOS default**:
   - Add a `defaults write ...` line in `install/macos/defaults.sh`
   - Add a matching `defaults read` check in the `defaults` section of `tests/audit.yaml`
   - No renaming needed: changing the script's hash makes chezmoi re-run it next apply

5. **Adding a brew package**: edit `home/dot_config/brew/Brewfile`. Next `chezmoi apply` will let `packages.sh` install it via `brew bundle install`. `check_brewfile formula/cask` in the audit will verify it.

6. **Adding a new chezmoi script**: always pick `run_once_before_*` or `run_once_after_*` explicitly. See the script naming note above.

7. **Don't edit `~/.local/share/tmux/oh-my-tmux/` directly.** That's the external git checkout; it gets reset on refresh. Your tmux tweaks belong in `~/.config/tmux/tmux.conf.local`.

8. **CI is not triggered by PRs.** `lint.yml` and `audit.yml` only run on push-to-main, manual dispatch, and the weekly schedule. This is deliberate: it keeps the `CHEZMOI_AGE_KEY` secret out of forked PR contexts.

9. **CI skips cask installs.** `audit.yml` greps `cask` lines out of the Brewfile before running `brew bundle install` (chrome / kitty / fonts are big downloads that drag macOS-runner time), and the audit step uses `--except casks` to match. A local `chezmoi apply` still installs everything.

10. **chezmoi keeps state by script hash.** A `run_once_*` script only runs the first time, but if you change its contents the hash changes and it runs again. The scripts therefore have to be idempotent — and they are: `install_homebrew` short-circuits when brew is present, `brew bundle install --no-upgrade` is a no-op when nothing's missing, `defaults write` is idempotent by definition.

11. **`rm` is a fish-only shield.** The wrapper at `home/dot_config/fish/functions/rm.fish` refuses to delete paths listed in three lists at the top of the file: `protected_files`, `protected_dirs`, and `protected_dirs_recursive`. Edit those lists in source, then `dots` to commit. Anything else passes through to the real `rm`. This only catches interactive fish shells — `command rm`, bash/zsh, scripts, cron jobs, and other non-fish callers bypass it.

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `chezmoi diff` shows changes to a file you didn't touch | A program edited it (e.g. nvim's `lazy-lock.json`). Pick or skip with `dots`. |
| audit `secrets decrypted` fails | `~/.config/chezmoi/age-key.txt` is missing, wrong, or not `chmod 600` |
| audit `external` fails | network issue or oh-my-tmux upstream change; retry with `chezmoi apply --refresh-externals` |
| A `run_once` script won't run | chezmoi state already recorded it ran. Either change the script's contents (changes its hash) or `chezmoi state delete-bucket --bucket=scriptState` to reset all `once` scripts. |
| `chezmoi apply` says "config file template has changed" | You edited `home/.chezmoi.toml.tmpl`. Run `chezmoi init` once to regenerate `~/.config/chezmoi/chezmoi.toml`. |
| CI audit fails at `brew bundle` | An upstream tap moved or a package disappeared from the Brewfile. Reproduce locally with `brew bundle check --file=~/.config/brew/Brewfile --verbose`. |

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
