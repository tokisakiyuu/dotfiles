function dotfile --description 'Manage dotfiles, private files, and environment backups'
    set -l dotfiles_root "$HOME"
    if set -q DOTFILES_SHELL_ROOT
        set dotfiles_root "$DOTFILES_SHELL_ROOT"
    end
    command /bin/bash "$dotfiles_root/.config/dotfiles/dotfile.sh" $argv
end
