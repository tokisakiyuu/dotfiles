function brewfile-sync --description 'Dump current brew state into the OS Brewfile'
    # macOS curates Brewfile (formulae + casks); Linux uses Brewfile.linux
    # (formulae only — Homebrew has no cask support on Linux).
    set -l bf "$HOME/.config/brew/Brewfile"
    if test (uname) != Darwin
        set bf "$HOME/.config/brew/Brewfile.linux"
    end

    if not command -q brew
        echo "brew not on PATH" >&2
        return 1
    end

    command brew bundle dump --file "$bf" --force; or return 1
    echo "✓ $bf updated."
end
