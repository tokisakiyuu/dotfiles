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
        case push
            chezmoi git -- push
        case pull
            chezmoi update
        case diff
            if test (count $argv) -gt 0; or not command -q fzf
                chezmoi diff --reverse $argv
                return
            end
            set -l changes (chezmoi status)
            if test (count $changes) -eq 0
                echo "dotfile: no changes"
                return 0
            end
            # status line is "XY path" (path relative to ~); {2..} is the path.
            # prints picked absolute paths on enter, ready for `dotfile add`
            printf '%s\n' $changes |
                fzf --multi \
                    --preview 'chezmoi diff --reverse --color=true $HOME/{2..}' \
                    --preview-window 'right,65%,wrap' \
                    --bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up' |
                string sub -s 4 |
                string replace -r '^' "$HOME/"
        case help '*'
            echo "usage:
  dotfile add [path ...] -m 'msg'   re-add file(s) (all modified if no path) and commit
  dotfile push                      push commits to upstream
  dotfile pull                      chezmoi update (pull + apply)
  dotfile diff [path ...]           reverse diff: local edits shown as additions" >&2
            test "$cmd" = help; and return 0
            return 1
    end
end
