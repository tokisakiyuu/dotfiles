function dots --description 'Sync ~ -> source, pick files, commit, push'
    # Pull remote + apply first so re-add can't clobber upstream commits.
    chezmoi update; or return 1

    set -l rows (chezmoi status)
    if test (count $rows) -eq 0
        echo "No changes."
        return 0
    end

    # Strip the leading "XY " status prefix, then fzf for multi-select.
    set -l targets (
        printf '%s\n' $rows \
        | string replace -r '^...' '' \
        | fzf --multi --reverse \
              --preview "chezmoi diff $HOME/{}" \
              --header 'Tab: toggle  Enter: confirm  Esc: abort'
    )

    if test (count $targets) -eq 0
        echo "Nothing selected."
        return 1
    end

    set -l abs_paths
    for t in $targets
        set -a abs_paths "$HOME/$t"
    end
    chezmoi re-add $abs_paths; or return 1

    set -l oldpwd $PWD
    cd (chezmoi source-path)/..

    git add -A
    git diff --cached --stat
    echo

    set -l rc 0
    read -l -P 'Commit message: ' msg
    if test -z "$msg"
        echo "Empty message, aborting."
        git reset >/dev/null
        set rc 1
    else if not git commit -m "$msg"
        set rc 1
    else
        git push; or set rc 1
    end

    cd $oldpwd
    return $rc
end
