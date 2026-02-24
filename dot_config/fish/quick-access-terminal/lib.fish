function __search
    set -l function_name $argv[1]
    set -l url_template $argv[2]
    set -l prompt_str $argv[3]

    if test -z "$prompt_str"
        set prompt_str "Question: "
    end

    eval "
    function $function_name
        if test (count \$argv) -gt 0
            set --local encoded_input (string escape --style=url -- \$argv)
            set --local url (string replace '{keyword}' \"\$encoded_input\" \"$url_template\")
            open \$url
            return
        end

        read --local --prompt-str \"$prompt_str\" user_input
        if test \$status -eq 130; or test -z \"\$user_input\"
            return
        end

        set --local encoded_input (string escape --style=url -- \$user_input)
        set --local url (string replace '{keyword}' \"\$encoded_input\" \"$url_template\")
        open \$url
    end
    "
end

function __open
    set -l name $argv[1]
    set -l url $argv[2]

    eval "
    function $name
        open \"$url\"
    end
    "
end

function __shortcuts
    set -l name $argv[1]
    set -l shortcut_name $argv[2]

    eval "
    function $name --wraps=shortcuts
        if test -z \"\$argv[1]\"
            return
        end
        echo \$argv[1] | shortcuts run \"$shortcut_name\"
    end
    "
end

function __cmd
    set -l name $argv[1]
    set -l cmd $argv[2]

    eval "
    function $name
        read --local user_input
        if test \$status -eq 130; or test -z \"\$user_input\"
            return
        end

        $cmd \$user_input
    end
    "
end
