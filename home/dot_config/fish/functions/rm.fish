function rm --wraps=rm --description 'rm wrapper that refuses to delete configured paths'
    # ── Protected paths ──────────────────────────────────────────────────────
    # Edit these three lists to taste. Paths may use ~ for $HOME.

    # Exact files that must never be rm'd.
    set -l protected_files \
        ~/.config/chezmoi/age-key.txt

    # Directories whose entry itself can't be rm'd. Children stay deletable.
    set -l protected_dirs

    # Directories AND every descendant: rm of the directory or anything
    # underneath it is refused.
    set -l protected_dirs_recursive \
        ~/.ssh

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

        for f in $protected_files
            if test "$rt" = (path resolve -- $f)
                echo "rm refused: $target is in protected_files" >&2
                return 1
            end
        end

        for d in $protected_dirs
            if test "$rt" = (path resolve -- $d)
                echo "rm refused: $target is in protected_dirs (the dir itself)" >&2
                return 1
            end
        end

        for d in $protected_dirs_recursive
            set -l rd (path resolve -- $d)
            if test "$rt" = "$rd"
                echo "rm refused: $target is a protected_dirs_recursive root" >&2
                return 1
            end
            if string match -q -- "$rd/*" $rt
                echo "rm refused: $target is inside protected_dirs_recursive $d" >&2
                return 1
            end
        end
    end

    command rm $argv
end
