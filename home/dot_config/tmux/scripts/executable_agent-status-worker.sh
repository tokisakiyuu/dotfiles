#!/bin/bash
# One worker per tmux server. Detect every ~2s; animate cached working states
# every 100ms. No agent hooks, external service, or disk cache. Bash 3.2+.

worker_dir=$(cd -- "${BASH_SOURCE[0]%/*}" && pwd) || exit 1
worker_script=$worker_dir/agent-status-worker.sh
animation_frames=('+' 'x' '*')

query_tmux() { "${tmux_cmd[@]}" "$@" 2>/dev/null; }

refresh_status() {
    local client
    local -a commands
    commands=()
    for client in "${clients[@]}"; do
        commands+=(refresh-client -S -t "$client" ';')
    done
    ((${#commands[@]})) && query_tmux "${commands[@]}" >/dev/null
}

publish_frame() {
    local frame=$1 client
    local -a commands
    commands=(set-option -g @agent-status-frame "$frame" ';')
    for client in "${clients[@]}"; do
        commands+=(refresh-client -S -t "$client" ';')
    done
    query_tmux "${commands[@]}" >/dev/null
}

poll_states() {
    local attached window previous previous_icon detected icon seen=' '
    working=0
    # Reload only the detector code, so rule fixes apply without a worker restart.
    # shellcheck source=./agent-status.sh
    source "$worker_dir/agent-status.sh" || return 1
    while IFS='|' read -r attached window previous previous_icon; do
        [[ $attached =~ ^[0-9]+$ && $window =~ ^@[0-9]+$ ]] || continue
        ((attached>0)) || continue
        [[ $seen == *" $window "* ]] && continue
        seen+="$window "
        # Each target is a window: the detector reads only its active pane.
        detected=$(main --window "$window" --socket "$socket" --state)
        case $detected in
            working) icon=' #{@agent-status-frame}' ;;
            waiting) icon=' ◉' ;;
            idle) icon=' ○' ;;
            *) detected=unknown; icon='' ;;
        esac
        [[ $detected != working ]] || working=1
        if [[ $detected != "$previous" || $icon != "$previous_icon" ]]; then
            query_tmux set-option -w -t "$window" @agent-status-state "$detected" ';' \
                set-option -w -t "$window" @agent-status-icon "$icon" >/dev/null
        fi
    done < <(query_tmux list-windows -a -F '#{session_attached}|#{window_id}|#{@agent-status-state}|#{@agent-status-icon}')
}

cleanup_worker() {
    local owner window
    owner=$(query_tmux show-options -gqv @agent-status-worker-pid) || return
    [[ $owner == "$$" ]] || return
    while IFS= read -r window; do
        query_tmux set-option -wu -t "$window" @agent-status-state ';' \
            set-option -wu -t "$window" @agent-status-icon >/dev/null
    done < <(query_tmux list-windows -a -F '#{window_id}')
    query_tmux set-option -gu @agent-status-worker-pid >/dev/null
}

run_worker() {
    local client working=0 index=0 tick owner
    local -a clients
    trap cleanup_worker EXIT
    trap 'exit 0' HUP INT TERM
    # Wait until the starter has published this child's PID and released its
    # startup lock before checking ownership (avoids a fast-child race).
    query_tmux wait-for -L agent-status-worker-start >/dev/null || return
    query_tmux wait-for -U agent-status-worker-start >/dev/null || return
    while :; do
        owner=$(query_tmux show-options -gqv @agent-status-worker-pid) || break
        [[ $owner == "$$" ]] || break
        clients=()
        while IFS= read -r client; do
            [[ -z $client ]] || clients+=("$client")
        done < <(query_tmux list-clients -F '#{client_name}')
        # client-attached restarts the worker when someone returns.
        ((${#clients[@]})) || break
        poll_states || break
        if ((working)); then
            for ((tick=0; tick<20; tick++)); do
                publish_frame "${animation_frames[index % ${#animation_frames[@]}]}" || return
                index=$(((index+1) % ${#animation_frames[@]}))
                sleep 0.1
            done
        else
            # No animation wakeups while all agents are waiting/idle/unknown.
            index=0
            refresh_status || return
            sleep 2
        fi
    done
}

start_worker() {
    local previous pid probe
    # Serialize reloads/attachments; hold the lock only during startup.
    query_tmux wait-for -L agent-status-worker-start || return
    trap 'query_tmux wait-for -U agent-status-worker-start >/dev/null || :' EXIT
    previous=$(query_tmux show-options -gqv @agent-status-worker-pid)
    if [[ $previous =~ ^[0-9]+$ ]]; then
        if probe=$(kill -0 "$previous" 2>&1); then return; fi
        # A sandbox can forbid probing a live worker; that is not evidence
        # that it died. Treat EPERM like a successful liveness check.
        case $probe in *'not permitted'*|*'Permission denied'*) return ;; esac
    fi
    query_tmux set-option -g @agent-status-frame "${animation_frames[0]}" >/dev/null || return
    /bin/bash "$worker_script" run "$socket" </dev/null >/dev/null 2>&1 &
    pid=$!
    query_tmux set-option -g @agent-status-worker-pid "$pid" >/dev/null
}

setup_worker() {
    local launch hook
    printf -v launch '/bin/bash %q start %q' "$worker_script" "$socket"
    printf -v hook 'run-shell -b %q' "$launch"
    query_tmux set-hook -g 'client-attached[19433]' "$hook" || return
    query_tmux set-option -g status-interval 2 || return
    start_worker
}

worker_main() {
    local mode=${1:-setup}
    socket=${2:-${TMUX_SOCKET:-}}
    tmux_cmd=("${TMUX_PROGRAM:-tmux}")
    [[ -z $socket ]] || tmux_cmd+=(-S "$socket")
    # Resolve the socket once for calls outside an existing tmux shell.
    socket=$(query_tmux display-message -p '#{socket_path}') || return 1
    case $mode in
        setup) setup_worker ;;
        start) start_worker ;;
        run) run_worker ;;
        *) printf 'Usage: agent-status-worker.sh [setup|start|run] [socket]\n' >&2; return 2 ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then worker_main "$@"; fi
