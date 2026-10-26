function zi-insert --description 'Pick a dir with zoxide+fzf, seeded by the word before the cursor'
    # `-tc` = current token, cut at the cursor: the text from the start of the
    # word under the cursor up to the cursor itself. This seeds fzf's filter.
    set -l query (commandline -tc)

    # `zoxide query -i <keywords>` opens the fzf picker pre-filtered by keywords.
    set -l result (zoxide query --interactive -- $query)

    if test -n "$result"
        # Replace the partial word with the picked path instead of appending,
        # so the seed word doesn't linger on the command line.
        commandline -rt -- (string escape -- $result)
    end
    commandline -f repaint
end
