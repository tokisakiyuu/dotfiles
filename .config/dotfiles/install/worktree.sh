#!/usr/bin/env bash

dotfiles_read_policy() {
    local repository=$1 worktree=$2 filename=$3
    if [[ -f "$worktree/$filename" ]]; then cat "$worktree/$filename";
    else
        git --git-dir="$repository" show ":$filename" 2>/dev/null ||
            git --git-dir="$repository" show "HEAD:$filename"
    fi
}

dotfiles_write_policy() {
    local target=$1 temporary
    temporary=$(mktemp "${target}.XXXXXX") || return 1
    if ! cat > "$temporary"; then rm -f "$temporary"; return 1; fi
    if [[ -f "$target" ]] && cmp -s "$temporary" "$target"; then rm -f "$temporary";
    else chmod 600 "$temporary" && mv -f "$temporary" "$target"; fi
}

dotfiles_refresh_ignores() {
    local repository=$1 worktree=$2
    local git_args=(--git-dir="$repository" --work-tree="$worktree" -C "$worktree")
    [[ $(git "${git_args[@]}" config --local --get core.sparseCheckout || true) == true ]] || return 0
    mkdir -p "$repository/info" || return 1
    { git "${git_args[@]}" show :.gitignore 2>/dev/null || git "${git_args[@]}" show HEAD:.gitignore; } |
        dotfiles_write_policy "$repository/info/dotfiles-ignore" || return 1
    git "${git_args[@]}" config --local core.excludesFile "$repository/info/dotfiles-ignore"
}

dotfiles_configure_worktree() {
    local repository=$1 worktree=$2
    local git_args=(--git-dir="$repository" --work-tree="$worktree" -C "$worktree")
    [[ $(git "${git_args[@]}" config --local --get dotfiles.fullWorktree || true) != true ]] || return 0
    mkdir -p "$repository/info" || return 1
    {
        git "${git_args[@]}" show :.config/dotfiles/install/sparse-checkout 2>/dev/null ||
            git "${git_args[@]}" show HEAD:.config/dotfiles/install/sparse-checkout 2>/dev/null ||
            cat "$worktree/.config/dotfiles/install/sparse-checkout"
    } | dotfiles_write_policy "$repository/info/sparse-checkout" || return 1
    git "${git_args[@]}" config --local core.sparseCheckout true || return 1
    git "${git_args[@]}" config --local core.sparseCheckoutCone false || return 1
    dotfiles_refresh_ignores "$repository" "$worktree"
}

dotfiles_reapply_worktree() {
    local repository=$1 worktree=$2
    [[ $(git --git-dir="$repository" config --local --get core.sparseCheckout || true) == true ]] || return 0
    dotfiles_configure_worktree "$repository" "$worktree" || return 1
    git --git-dir="$repository" --work-tree="$worktree" -C "$worktree" sparse-checkout reapply
}

dotfiles_materialize_policy() {
    local repository=$1 worktree=$2 filename=$3
    [[ ! -e "$worktree/$filename" ]] || return 0
    git --git-dir="$repository" --work-tree="$worktree" -C "$worktree" \
        checkout --ignore-skip-worktree-bits -- "$filename"
}

dotfiles_preserve_staged_metadata() {
    local repository=$1 worktree=$2 filename
    shift 2
    [[ $(git --git-dir="$repository" config --local --get core.sparseCheckout || true) == true ]] || return 0
    while IFS= read -r -d '' filename; do
        case "$filename" in
            README.md|.gitignore|.gitattributes|.github/*)
                dotfiles_materialize_policy "$repository" "$worktree" "$filename" || return 1 ;;
        esac
    done < <(git --git-dir="$repository" --work-tree="$worktree" -C "$worktree" \
        diff --cached --name-only -z --diff-filter=ACMRT -- "$@")
}

dotfiles_stage_present_metadata() {
    local repository=$1 worktree=$2 filename
    [[ $(git --git-dir="$repository" config --local --get core.sparseCheckout || true) == true ]] || return 0
    while IFS= read -r -d '' filename; do
        if [[ -f "$worktree/$filename" || -L "$worktree/$filename" ]]; then
            git --git-dir="$repository" --work-tree="$worktree" -C "$worktree" \
                add --sparse --renormalize -- "$filename" || return 1
        fi
    done < <(git --git-dir="$repository" --work-tree="$worktree" -C "$worktree" \
        ls-files -z -- README.md .gitignore .gitattributes .github)
}
