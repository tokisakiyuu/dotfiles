function brewfile-sync --description 'Dump current brew state into ~/.config/brew/Brewfile'
    set -l bf "$HOME/.config/brew/Brewfile"

    if not command -q brew
        echo "brew not on PATH" >&2
        return 1
    end

    command brew bundle dump --file "$bf" --force; or return 1
    echo "✓ $bf updated. Run 'dots' to commit."
end
