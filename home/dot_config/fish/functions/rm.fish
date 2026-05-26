function rm --wraps=rm --description 'rm wrapper that refuses to delete configured paths'
    # ── Protected paths ──────────────────────────────────────────────────────
    # Add / remove entries by editing the `set -a` lines below.
    # Each line is independent — no trailing backslashes, no comma fiddling.
    # Paths may use ~ for $HOME.

    # Exact paths (file or directory) that must never be rm'd.
    set -l protected_paths
    set -a protected_paths ~/.config/chezmoi/age-key.txt

    # Directory roots whose contents are also off-limits: rm of the directory
    # itself, or anything underneath it, is refused.
    set -l protected_paths_recursive
    set -a protected_paths_recursive ~/.ssh

    # ── Pull file targets out of argv (skip flags) ───────────────────────────
    set -l targets
    set -l past_dashdash 0
    for arg in $argv
        if test $past_dashdash -eq 1
            set -a targets $arg
            continue
        end
        if test "$arg" = '--'
            set past_dashdash 1
            continue
        end
        if string match -q -- '-*' $arg
            continue
        end
        set -a targets $arg
    end

    # ── Refuse if any target hits a protection rule ──────────────────────────
    for target in $targets
        set -l rt (path resolve -- $target)

        for p in $protected_paths
            if test "$rt" = (path resolve -- $p)
                echo "rm refused: $target is in protected_paths" >&2
                return 1
            end
        end

        for p in $protected_paths_recursive
            set -l rp (path resolve -- $p)
            if test "$rt" = "$rp"
                echo "rm refused: $target is a protected_paths_recursive root" >&2
                return 1
            end
            if string match -q -- "$rp/*" $rt
                echo "rm refused: $target is inside protected_paths_recursive $p" >&2
                return 1
            end
        end
    end

    command rm $argv
end
