function app
    set -l name (ls /Applications | sed 's/\.app$//' | fzf)

    if test -z "$name"
        return
    end

    open "/Applications/$name.app"
end
