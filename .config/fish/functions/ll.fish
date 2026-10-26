function ll --wraps=eza --description 'List contents of directory using exa'
    if set -q argv[1]; and contains -- $argv[1] -j --jump
        __ll_jump $argv[2..]
        return
    end
    eza --icons --color always --classify --sort modified $argv
end

function __ll_jump --description "interactive directory jump via eza + fzf (ll -j)"
    set -l dir (pwd)
    if set -q argv[1]
        set dir (path resolve $argv[1])
        if not test -d $dir
            echo "ll -j: not a directory: $argv[1]" >&2
            return 1
        end
    end
    while true
        set -l sel (begin
                printf '.\n..\n'
                eza -1 --only-dirs --color=always $dir
            end | fzf --ansi --reverse --height 50% \
                --prompt "$dir/" \
                --preview "eza -1 --only-dirs --color=always '$dir'/{}")
        or return # cancelled via ESC / Ctrl-C
        if test "$sel" = "."
            cd $dir
            return
        end
        set dir (path normalize $dir/$sel)
    end
end
