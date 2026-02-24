function app
    set -l name (ls /Applications | sed 's/\.app$//' | fzf)

    if test -z "$name"
        return
    end

    open "/Applications/$name.app"
end

function open
    set -l input $argv[1]

    if string match -rq '^https?://' $input
        command open $input
    else
        command open https://$input
    end
end
