function brew --wraps=brew --description 'Homebrew with automatic per-machine Brewfile snapshots'
    command brew $argv
    set -l brew_status $status

    set -l snapshot 0
    switch "$argv[1]"
        case install uninstall remove rm reinstall autoremove tap untap upgrade pin unpin
            set snapshot 1
        case bundle
            switch "$argv[2]"
                case '' install upgrade cleanup add remove '-*'
                    set snapshot 1
            end
    end
    for flag in --help -h --dry-run -n
        if contains -- "$flag" $argv
            set snapshot 0
        end
    end

    # Failed installs can still install some dependencies; snapshot their state too.
    if test $snapshot -eq 1
        if not _brew_snapshot
            printf '%s\n' 'brew: operation finished, but the Brewfile snapshot failed.' >&2
        end
    end
    return $brew_status
end

function _brew_snapshot
    set -l machine_file "$HOME/.config/dotfiles/machine"
    if not test -r "$machine_file"
        printf '%s\n' 'Set the machine name with: bash ~/.config/dotfiles/setup.sh MACHINE --configure-only' >&2
        return 1
    end
    set -l machine (string trim -- (cat "$machine_file"))
    string match -rq -- '^[A-Za-z0-9][A-Za-z0-9._-]*$' "$machine"; or return 1

    set -l snapshot_dir "$HOME/.config/brew"
    mkdir -p "$snapshot_dir"; or return 1
    set -l temporary (mktemp "$snapshot_dir/.Brewfile.$machine.XXXXXX"); or return 1
    if command brew bundle dump --force --no-describe --file="$temporary"
        set -l target "$snapshot_dir/Brewfile.$machine"
        if test -f "$target"; and command cmp -s -- "$temporary" "$target"
            command rm -f -- "$temporary"; or return 1
        else
            command mv -f -- "$temporary" "$target"; or return 1
        end
        # Make a first snapshot visible even with untracked files hidden.
        if test -d "$HOME/.dotfiles.git"
            if not command git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" \
                    ls-files --error-unmatch -- "$target" >/dev/null 2>&1
                command git --git-dir="$HOME/.dotfiles.git" --work-tree="$HOME" \
                    add --intent-to-add -- "$target"; or return 1
            end
        end
        return 0
    end
    command rm -f -- "$temporary"
    return 1
end
