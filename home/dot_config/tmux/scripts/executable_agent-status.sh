#!/bin/bash
# Read only the active pane of one window; no agent hooks, daemon or state files.
# Bash 3.2 compatible. External commands: tmux, plus ps for wrapped processes.
# ● working, ◉ needs input, ○ idle; unknown states and ordinary shells stay hidden.
# UI heuristics informed by https://github.com/snirt/agenmux.

shopt -s nocasematch

agent_for_bin() {
    local name=${1##*/}
    case $name in *.js|*.cmd|*.exe) name=${name%.*} ;; esac
    case $name in
        codex) agent=codex ;;
        claude|claude-code) agent=claude ;;
        opencode|open-code) agent=opencode ;;
        *) return 1 ;;
    esac
}

is_runtime() {
    case $1 in
        sh|bash|zsh|fish|dash|ksh|nu|pwsh|node|bun|deno|env|npm|npx|pnpm|yarn|python|python3|uv) return 0 ;;
        *) return 1 ;;
    esac
}

# Tokenize ps arguments without eval or executing their contents.
split_argv() {
    local text=$1 word='' quote='' char escaped=0 started=0 i
    argv=()
    for ((i=0; i<${#text}; i++)); do
        char=${text:i:1}
        if ((escaped)); then
            word+=$char; escaped=0; started=1
        elif [[ $char == \\ && $quote != "'" ]]; then
            escaped=1; started=1
        elif [[ -n $quote ]]; then
            if [[ $char == "$quote" ]]; then quote=; else word+=$char; fi
        elif [[ $char == '"' || $char == "'" ]]; then
            quote=$char; started=1
        elif [[ $char == ' ' || $char == $'\t' ]]; then
            if ((started)); then argv+=("$word"); word=; started=0; fi
        else
            word+=$char; started=1
        fi
    done
    [[ -z $quote && $escaped == 0 ]] || return 1
    if ((started)); then argv+=("$word"); fi
}

agent_from_commandline() {
    local name arg i
    local -a argv
    split_argv "$1" || return 1
    ((${#argv[@]})) || return 1
    agent_for_bin "${argv[0]}" && return 0
    name=${argv[0]##*/}
    is_runtime "$name" || return 1
    for ((i=1; i<${#argv[@]}; i++)); do
        arg=${argv[i]}
        case $arg in
            -c|-e|--eval|-p|--print) return 1 ;;
            -*) continue ;;
            *) agent_for_bin "$arg"; return $? ;;
        esac
    done
    return 1
}

identify_agent() {
    local command=$1 tty=$2 name pgid tpgid args
    local version_pattern='^[0-9]+(\.[0-9]+){1,3}$'
    local tty_pattern='^/dev/[A-Za-z0-9/_-]+$'
    agent=
    agent_for_bin "$command" && return 0
    name=${command##*/}
    # Editors own their panes even when they launch an agent internally.
    # Native Claude builds may expose a version number as their process name.
    is_runtime "$name" || [[ $name =~ $version_pattern ]] || return 1
    [[ $tty =~ $tty_pattern ]] || return 1
    while read -r pgid tpgid args; do
        # Background jobs sharing the tty must not claim its foreground pane.
        [[ $pgid == "$tpgid" && $tpgid != 0 && $tpgid != -1 ]] || continue
        agent_from_commandline "$args" && return 0
    done < <(ps -t "${tty#/dev/}" -o pgid=,tpgid=,args= 2>/dev/null)
    return 1
}

matches_lines() {
    local pattern=$1 line
    shift
    for line in "$@"; do
        [[ $line =~ $pattern ]] && return 0
    done
    return 1
}

set_state() { state=$1; reason=$2; }

classify_codex() {
    local title=$1 screen=$2 cursor_row=${3:--1} line i composer=-1 start
    local -a lines nearby controls footer
    local composer_pattern='^›([[:space:]]|$)'
    local activity='^([•●][[:space:]]+)?[^[:space:]].*\([[:space:]]*[0-9]+([.,][0-9]+)?[[:space:]]*[smh].*[•·].*(esc|ctrl\+c) (again )?to interrupt\)[[:space:]]*$'
    local confirmation='^[[:space:]]*(press[[:space:]]+)?enter to (confirm|submit (answer|all)).*(esc to cancel|$)'
    local spinner='^[⠀-⣿◐◓◑◒][[:space:]]'
    local help='^[[:space:]]{0,2}\? for shortcuts([[:space:]]|$)'
    local required='action required'
    local cursor_pattern='^[0-9]+$'
    lines=(); nearby=(); controls=(); footer=()
    # Keep the whole screen so a tall custom status line does not hide the UI.
    while IFS= read -r line; do lines+=("$line"); done <<< "${screen//$'\xc2\xa0'/ }"
    for ((i=0; i<${#lines[@]}; i++)); do
        [[ ${lines[i]} =~ $composer_pattern ]] && composer=$i
    done
    for ((i=0; i<${#lines[@]}; i++)); do
        if ((composer>=0 && i>=composer)); then break; fi
        line=${lines[i]}
        [[ $line =~ [^[:space:]] ]] || continue
        nearby+=("$line")
        if ((${#nearby[@]}>6)); then nearby=("${nearby[@]:1}"); fi
    done
    # Match the unindented, timed activity row, never shortcuts quoted in prose.
    if matches_lines "$activity" "${nearby[@]}"; then
        set_state working 'live activity row above composer'; return
    fi
    if ((composer>=0)); then
        controls=("${nearby[@]}")
        footer=("${lines[@]:composer+1}")
    else
        start=$((${#lines[@]}>8 ? ${#lines[@]}-8 : 0))
        controls=("${lines[@]:start}")
    fi
    # Custom status-line content below a composer is never checked for keywords.
    if matches_lines "$confirmation" "${controls[@]}"; then
        set_state waiting 'bottom confirmation controls'; return
    fi
    if [[ $title =~ $spinner ]]; then
        set_state working 'title spinner'; return
    fi
    if ((composer>=0)) && matches_lines "$help" "${footer[@]}"; then
        set_state idle 'composer and shortcut-help footer; no live activity row'; return
    fi
    if [[ $title =~ $required ]]; then
        set_state waiting 'approval title'; return
    fi
    # Typing replaces the shortcut-help row. The live input cursor still
    # identifies the composer, including wrapped or multiline drafts. Requiring
    # that cursor avoids mistaking an old submitted prompt for an idle input.
    if ((composer>=0)) && [[ $cursor_row =~ $cursor_pattern ]] &&
        ((cursor_row>=composer && cursor_row<${#lines[@]})); then
        set_state idle 'input cursor inside composer; no live activity row'; return
    fi
    set_state unknown 'no recognized Codex UI controls'
}

classify_opencode() {
    local screen=$1 line i start border=-1
    local -a lines footer tail
    local border_pattern='^[[:space:]]*╹▀{3,}'
    local interrupt='(esc|ctrl\+c)[[:space:]]+((again[[:space:]]+)?to[[:space:]]+)?interrupt'
    local idle_footer='commands([[:space:]]|$)|^[[:space:]]*(~|/|[A-Za-z]:[/\\])|esc[[:space:]]+exit shell mode'
    local form='esc (dismiss|close).*enter (confirm|submit|toggle|choose|next|save)|enter (confirm|submit|toggle|choose|next|save).*esc (dismiss|close)'
    local confirm='enter[[:space:]]+confirm([[:space:]]|$)'
    lines=(); footer=()
    while IFS= read -r line; do lines+=("$line"); done <<< "${screen//$'\xc2\xa0'/ }"
    for ((i=0; i<${#lines[@]}; i++)); do
        [[ ${lines[i]} =~ $border_pattern ]] && border=$i
    done
    if ((border>=0)); then
        # OpenCode v2 puts its live status BELOW the composer's bottom edge.
        # Never scan the conversation above it for state words or progress bars.
        footer=("${lines[@]:border+1}")
        if matches_lines "$interrupt|(■|⬝){4,}" "${footer[@]}"; then
            set_state working 'OpenCode composer footer interrupt control'; return
        fi
        if matches_lines "$idle_footer" "${footer[@]}"; then
            set_state idle 'OpenCode composer border and idle footer'; return
        fi
        set_state unknown 'unrecognized OpenCode composer footer'; return
    fi
    start=$((${#lines[@]}>8 ? ${#lines[@]}-8 : 0))
    footer=("${lines[@]:start}")
    # Permission/question panes replace the regular composer. v2 permission
    # controls have "enter confirm" without the old "esc dismiss" hint.
    if matches_lines "$form" "${footer[@]}"; then
        set_state waiting 'OpenCode question controls'; return
    fi
    start=$((${#lines[@]}>20 ? ${#lines[@]}-20 : 0))
    tail=("${lines[@]:start}")
    if matches_lines "$confirm" "${footer[@]}" &&
        { matches_lines '^[[:space:]┃│]*△[[:space:]]+Permission required' "${tail[@]}" ||
          matches_lines '⇆[[:space:]]+select' "${footer[@]}"; }; then
        set_state waiting 'OpenCode permission confirmation controls'; return
    fi
    # Retain support for older OpenCode UIs, using only the bottom controls.
    if matches_lines "$interrupt|(■|⬝){4,}" "${footer[@]}"; then
        set_state working 'OpenCode interrupt control'; return
    fi
    if matches_lines '^[[:space:]]*[›❯>][[:space:]]*|ask anything|tab (agents|switch agent)' "${footer[@]}"; then
        set_state idle 'OpenCode input prompt'; return
    fi
    set_state unknown 'no recognized OpenCode UI controls'
}

classify() {
    local agent=$1 title=$2 screen=$3 cursor_row=${4:--1} line start
    local -a lines tail
    local spinner='^[⠀-⣿◐◓◑◒][[:space:]]'
    local interrupt='(esc|ctrl\+c) (again )?to interrupt'
    local prompt='^[[:space:]]*[›❯>][[:space:]]*'
    if [[ $agent == codex ]]; then classify_codex "$title" "$screen" "$cursor_row"; return; fi
    if [[ $agent == opencode ]]; then classify_opencode "$screen"; return; fi
    lines=()
    while IFS= read -r line; do lines+=("$line"); done <<< "${screen//$'\xc2\xa0'/ }"
    start=$((${#lines[@]}>20 ? ${#lines[@]}-20 : 0))
    tail=("${lines[@]:start}")
    case $agent in
        claude)
            if [[ $title =~ $spinner ]] || matches_lines "$interrupt" "${tail[@]}" ||
                matches_lines '^[[:space:]]*[*·✢✳✶✻✽][[:space:]]+.+…[[:space:]]*(\(|$)' "${tail[@]}"; then
                set_state working 'activity indicator'; return
            fi
            if matches_lines '^[[:space:]]*❯[[:space:]]*$' "${tail[@]}"; then
                set_state idle 'empty input prompt'; return
            fi
            if matches_lines 'do you want to (proceed|allow)|waiting for permission|tab to amend|ctrl\+e to explain|enter to select.*esc to cancel|esc to cancel.*enter to select' "${tail[@]}"; then
                set_state waiting 'permission prompt'; return
            fi
            if matches_lines "$prompt|\? for shortcuts" "${tail[@]}"; then
                set_state idle 'input prompt'; return
            fi ;;
    esac
    set_state unknown 'no recognized screen or title marker'
}

usage() {
    printf '%s\n' 'Usage: agent-status.sh [--window @ID | --pane %ID] [--socket PATH] [--debug | --state]' \
        'Defaults to TMUX_PANE. Debug prints the pane, agent, state and reason.'
}

main() {
    local selected='' socket='' debug=0 state_only=0 info pane command tty dead cursor_row title screen agent='' state=unknown reason=''
    local target_pattern='^[@%][0-9]+$'
    local -a tmux_cmd
    while (($#)); do
        case $1 in
            --window|--pane)
                [[ $# -ge 2 && -z $selected ]] || { usage >&2; return 2; }
                selected=$2; shift 2 ;;
            --socket)
                [[ $# -ge 2 ]] || { usage >&2; return 2; }
                socket=$2; shift 2 ;;
            --debug) debug=1; shift ;;
            --state) state_only=1; shift ;;
            -h|--help) usage; return ;;
            *) usage >&2; return 2 ;;
        esac
    done
    selected=${selected:-${TMUX_PANE:-}}
    [[ $selected =~ $target_pattern ]] || { usage >&2; return 2; }
    tmux_cmd=("${TMUX_PROGRAM:-tmux}")
    [[ -z $socket ]] || tmux_cmd+=(-S "$socket")
    # A window target resolves to its active pane, including inactive windows.
    if ! info=$("${tmux_cmd[@]}" display-message -p -t "$selected" \
        '#{pane_id}|#{pane_current_command}|#{pane_tty}|#{pane_dead}|#{cursor_y}|#{pane_title}' 2>/dev/null); then
        if ((debug)); then printf 'target=%s reason=tmux query failed\n' "$selected"; fi
        return
    fi
    IFS='|' read -r pane command tty dead cursor_row title <<< "$info"
    reason='no agent in the foreground'
    if [[ $dead != 1 ]] && identify_agent "$command" "$tty"; then
        if screen=$("${tmux_cmd[@]}" capture-pane -p -t "$pane" 2>/dev/null); then
            classify "$agent" "$title" "$screen" "$cursor_row"
        else
            reason='pane capture failed'
        fi
    fi
    if ((debug)); then
        printf 'pane=%s agent=%s state=%s reason=%s\n' "$pane" "${agent:-none}" "$state" "$reason"
    elif ((state_only)); then
        printf '%s\n' "$state"
    elif [[ -n $agent ]]; then
        case $state in
            working) printf ' ●\n' ;;
            waiting) printf ' ◉\n' ;;
            idle) printf ' ○\n' ;;
        esac
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
