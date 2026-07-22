function dotfile -d "chezmoi daily maintenance"
    set -l cmd $argv[1]
    set -e argv[1]

    switch "$cmd"
        case add
            argparse 'm/message=' -- $argv
            or return 1
            if not set -q _flag_message
                echo "usage: dotfile add [path ...] -m 'commit message'" >&2
                return 1
            end
            # sync repo only (no apply) so the later push won't conflict;
            # full pull+apply is `dotfile pull`
            set -l before (chezmoi git -- rev-parse HEAD)
            chezmoi git -- pull --rebase --autostash; or return
            set -l after (chezmoi git -- rev-parse HEAD)
            chezmoi re-add $argv; or return
            chezmoi git -- commit -am "$_flag_message"; or return
            if test "$before" != "$after"
                echo "note: remote had new commits; run 'dotfile pull' to apply them to this machine"
            end
            # quote @{u}: fish brace expansion would turn it into @u
            set -l ahead (chezmoi git -- rev-list --count '@{u}..HEAD' 2>/dev/null)
            if test -n "$ahead"; and test $ahead -gt 0
                echo "note: $ahead commit(s) unpushed — run 'dotfile push'"
            end
        case status
            set -l changes (_dotfile_changes)
            if test (count $changes) -eq 0
                echo "dotfile: no changes"
                return 0
            end
            printf '%s\n' $changes
        case push
            chezmoi git -- push
        case pull
            chezmoi update
        case diff
            if test (count $argv) -gt 0; or not command -q fzf
                chezmoi diff --reverse $argv
                return
            end
            set -l changes (_dotfile_changes)
            if test (count $changes) -eq 0
                echo "dotfile: no changes"
                return 0
            end
            # line is "XY path" (path relative to ~); {2..} is the path.
            # ">>" rows preview the unpushed commit diff; encrypted sources fall
            # back to decrypted current content (git diff would show ciphertext).
            # prints picked absolute paths on enter, ready for `dotfile add`
            set -l preview '
                if test {1} = ">>"
                    set sp (chezmoi source-path $HOME/{2..})
                    if string match -q "*encrypted_*" $sp
                        echo "(encrypted file — showing current decrypted content instead of commit diff)"
                        chezmoi cat $HOME/{2..}
                    else
                        chezmoi git -- diff --color=always "@{u}..HEAD" -- $sp
                    end
                else
                    chezmoi diff --reverse --color=true $HOME/{2..}
                end'
            printf '%s\n' $changes |
                fzf --multi \
                    --header '>> = committed but not pushed' \
                    --preview $preview \
                    --preview-window 'right,65%,wrap' \
                    --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' |
                string sub -s 4 |
                string replace -r '^' "$HOME/"
        case help '*'
            echo "usage:
  dotfile add [path ...] -m 'msg'   re-add file(s) (all modified if no path) and commit
  dotfile status                    list changed files (>> = committed but not pushed)
  dotfile push                      push commits to upstream
  dotfile pull                      chezmoi update (pull + apply)
  dotfile diff [path ...]           reverse diff: local edits shown as additions" >&2
            test "$cmd" = help; and return 0
            return 1
    end
end

# changed files, one per line: "XY path" from chezmoi status,
# plus ">> path" for files touched by committed-but-unpushed commits
function _dotfile_changes
    chezmoi status
    set -l repo (chezmoi git -- rev-parse --show-toplevel 2>/dev/null)
    for f in (chezmoi git -- diff --name-only '@{u}..HEAD' 2>/dev/null)
        set -l target (chezmoi target-path "$repo/$f" 2>/dev/null)
        or continue
        echo ">> "(string replace -- "$HOME/" '' $target)
    end
end
