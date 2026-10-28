# Match command positions so `key status` does not inherit `status` options.
function __fish_dotfile_command --argument-names command action --description 'Match the dotfile command path'
    set -l words (commandline -opc)
    test (count $words) -ge 2; and test "$words[2]" = "$command"; or return 1
    if test (count $argv) -eq 2
        test (count $words) -ge 3; and test "$words[3]" = "$action"; or return 1
    end
    return 0
end

complete -c dotfile -e -w git
complete -c dotfile -e
complete -c dotfile -f
complete -c dotfile -n 'test (count (commandline -opc)) -le 2; or __fish_dotfile_command key rotate' -l help -s h -d 'Show command help'
complete -c dotfile -n __fish_use_subcommand -a help -d 'Show command help'
complete -c dotfile -n __fish_use_subcommand -a status -d 'Show changes and encryption labels'
complete -c dotfile -n __fish_use_subcommand -a diff -d 'Review changes'
complete -c dotfile -n __fish_use_subcommand -a add -d 'Stage files or all tracked changes'
complete -c dotfile -n __fish_use_subcommand -a remove -d 'Stop tracking; preserve local files'
complete -c dotfile -n __fish_use_subcommand -a unstage -d 'Remove changes from staging'
complete -c dotfile -n __fish_use_subcommand -a commit -d 'Commit staged changes with a message'
complete -c dotfile -n __fish_use_subcommand -a log -d 'Show recent commits'
complete -c dotfile -n __fish_use_subcommand -a pull -d 'Pull with fast-forward only'
complete -c dotfile -n __fish_use_subcommand -a push -d 'Push with encryption checks'
complete -c dotfile -n __fish_use_subcommand -a verify -d 'Verify staged ciphertext'
complete -c dotfile -n __fish_use_subcommand -a lazygit -d 'Open dotfiles in lazygit'
complete -c dotfile -n __fish_use_subcommand -a shell -d 'Edit the full repository in a temporary fish shell'
complete -c dotfile -n __fish_use_subcommand -a key -d 'Manage the text unlock key'
complete -c dotfile -n '__fish_dotfile_command key; and test (count (commandline -opc)) -eq 2' -a status -d 'Check the key format without revealing its contents'
complete -c dotfile -n '__fish_dotfile_command key; and test (count (commandline -opc)) -eq 2' -a normalize -d 'Convert the local key to its lossless text format'
complete -c dotfile -n '__fish_dotfile_command key; and test (count (commandline -opc)) -eq 2' -a unlock -d 'Unlock files or resume an interrupted unlock'
complete -c dotfile -n '__fish_dotfile_command key; and test (count (commandline -opc)) -eq 2' -a rotate -d 'Rotate the key with verification and backups'
complete -c dotfile -n '__fish_dotfile_command key rotate' -l cancel -d 'Cancel the prepared rotation; keep the active key'
complete -c dotfile -n '__fish_dotfile_command status' -l all -d 'Include eligible untracked files'
complete -c dotfile -n '__fish_dotfile_command add' -l encrypt -d 'Declare the named files private and stage ciphertext'
complete -c dotfile -n '__fish_dotfile_command diff' -l staged -d 'Review staged changes instead of unstaged changes'
complete -c dotfile -n '__fish_dotfile_command log' -l limit -x -a '10 20 50 100' -d 'Maximum commits, from 1 to 1000 (default: 10)'
complete -c dotfile -n '__fish_dotfile_command add; or __fish_dotfile_command remove; or __fish_dotfile_command unstage; or __fish_dotfile_command diff' -F
