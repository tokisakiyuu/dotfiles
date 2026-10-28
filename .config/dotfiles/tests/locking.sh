#!/bin/bash
set -euo pipefail
[[ -n ${BASH_SOURCE[0]:-} ]] || { echo 'This script requires a file path; run it with bash /path/to/script.' >&2; exit 2; }
umask 077
metadata=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
stage=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-lock-test.XXXXXX")
owner='' worker_pid=''
cleanup() {
    if [[ -n "$owner" ]]; then
        if [[ -n "$worker_pid" ]]; then kill "$worker_pid" 2>/dev/null || true; fi
        kill "$owner" 2>/dev/null || true
        wait "$owner" 2>/dev/null || true
    fi
    rm -rf -- "$stage"
}
trap cleanup EXIT
cat > "$stage/driver.sh" <<'DRIVER'
#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1090 # The test passes the production helper as an explicit argument.
source "$1"
shift
dotfiles_exec_locked "$@"
DRIVER
cat > "$stage/worker.sh" <<'WORKER'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$$" > "$1/pid"
touch "$1/ready"
for ((attempt=0; attempt<400; attempt++)); do
    [[ ! -f "$1/release" ]] || exit 0
    sleep 0.05
done
exit 99
WORKER
locked() { /bin/bash "$stage/driver.sh" "$metadata/install/lib.sh" "$stage/lock with spaces" "$@"; }
start_worker() {
    local attempt
    rm -f "$stage/ready" "$stage/release" "$stage/pid"
    worker_pid=''
    locked /bin/bash "$stage/worker.sh" "$stage" > "$stage/owner.log" 2>&1 &
    owner=$!
    for ((attempt=0; attempt<100; attempt++)); do
        if [[ -f "$stage/ready" ]]; then worker_pid=$(cat "$stage/pid"); return 0; fi
        sleep 0.05
    done
    cat "$stage/owner.log" >&2
    echo 'The lock owner did not start.' >&2
    return 1
}
start_worker
if locked touch "$stage/competitor" > "$stage/competitor.log" 2>&1; then
    echo 'A second command acquired an already held lock.' >&2; exit 1
fi
[[ ! -e "$stage/competitor" ]]
touch "$stage/release"
wait "$owner"
owner='' worker_pid=''
[[ -f "$stage/lock with spaces" ]]
locked touch "$stage/reacquired"
[[ -f "$stage/reacquired" ]]
echo 'PASS: a real exclusive lock rejects concurrent commands and can be reacquired with the same lock file after normal exit.'
start_worker
kill -TERM "$worker_pid"
if wait "$owner"; then echo 'A terminated worker unexpectedly succeeded.' >&2; exit 1; fi
owner='' worker_pid=''
locked touch "$stage/after-signal"
[[ -f "$stage/after-signal" ]]
echo 'PASS: terminating the real worker releases the kernel lock without manual lock-file deletion.'
