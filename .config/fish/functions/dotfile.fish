function dotfile --description 'Manage dotfiles, private files, and environment backups'
    command /bin/bash "$HOME/.config/dotfiles/dotfile.sh" $argv
end
