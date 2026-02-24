# https://gist.github.com/bmhatfield/f613c10e360b4f27033761bbee4404fd
function keychain-env -d "Managing environment variable."
    argparse d= -- $argv
    or return

    if set -q _flag_d
        security delete-generic-password -a $USER -D "environment variable" -s "$_flag_d"
        return 0
    else
        switch (count $argv)
            case 2
                read -l -P "Are you sure to update the value of $argv[1]? [y/N] " confirm
                switch $confirm
                    case Y y
                        security add-generic-password -U -a $USER -D "environment variable" -s "$argv[1]" -w "$argv[2]"
                end
            case 1
                security find-generic-password -w -a $USER -D "environment variable" -s "$argv[1]"
        end
        return 0
    end

end
