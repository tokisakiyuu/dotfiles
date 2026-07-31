function zi-insert --description 'Pick a dir with zoxide+fzf and insert it at the cursor'
    # `zoxide query -i` is what `zi` wraps: it prints the picked path instead
    # of cd-ing, which is exactly what we want here.
    set -l result (zoxide query --interactive)
    if test -n "$result"
        commandline -i -- (string escape -- $result)
    end
    commandline -f repaint
end
