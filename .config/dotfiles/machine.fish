set -l machine_file "$HOME/.config/dotfiles/machine"
if test -r "$machine_file"
    set -gx DOTFILES_MACHINE (string trim -- (cat "$machine_file"))
    if string match -rq -- '^[A-Za-z0-9][A-Za-z0-9._-]*$' "$DOTFILES_MACHINE"
        set -l machine_config "$HOME/.config/dotfiles/machines/$DOTFILES_MACHINE.fish"
        test -r "$machine_config"; and source "$machine_config"
    end
end

set -l local_config "$HOME/.config/dotfiles/local.fish"
test -r "$local_config"; and source "$local_config"
