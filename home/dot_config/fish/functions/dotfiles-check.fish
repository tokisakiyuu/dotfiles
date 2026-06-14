function dotfiles-check --description 'Lint dotfiles before pushing'
    set -l src (chezmoi source-path)
    pushd $src/.. >/dev/null

    set -l rc 0

    set -l shell_targets setup.sh
    # Lint every per-OS install script that exists in this checkout.
    for d in install/macos install/postmarketos
        if test -d $d
            for f in $d/*.sh
                test -f $f; and set -a shell_targets $f
            end
        end
    end

    echo '▶ shellcheck'
    shellcheck $shell_targets; or set rc 1

    echo '▶ fish -n'
    for f in (find home/dot_config/fish -name '*.fish')
        fish -n $f; or set rc 1
    end

    echo '▶ chezmoi templates'
    for f in (find home -name '*.tmpl')
        chezmoi execute-template <$f >/dev/null; or set rc 1
    end

    echo '▶ chezmoi diff'
    chezmoi diff

    popd >/dev/null
    return $rc
end
