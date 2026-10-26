# Keeps the Mac awake (idle + lid close) and beeps on low battery / overheating.
# Nothing is persisted: every setting it touches is restored on exit.
#
# Usage:  stayawake            # full protection, asks for admin password
#         stayawake --no-lid   # idle sleep only, no password needed
#         stayawake --reset    # clear a leftover disablesleep flag and exit

function stayawake --description 'Keep the Mac awake, beep on low battery / overheating'
    if test "$argv[1]" = --reset
        sudo pmset -a disablesleep 0
        __stayawake_log "SleepDisabled = $(pmset -g | awk '/SleepDisabled/{print $2}')"
        return 0
    end

    # caffeinate runs the monitor as its child rather than alongside it, so Ctrl-C
    # kills the whole chain and releases the assertions. A backgrounded caffeinate
    # would survive Ctrl-C and then block `exit` as a lingering job. The child shell
    # also gives the watchdog a real pid to track — a fish function has none.
    caffeinate -i -m -s fish -c "source "(functions --details stayawake)"; __stayawake_run $argv"
end

function __stayawake_run
    set -g __stayawake_warn 20
    set -g __stayawake_critical 10
    set -g __stayawake_clear 25
    set -g __stayawake_repeat 300
    set -g __stayawake_last_battery 0
    set -g __stayawake_last_thermal 0
    set -l poll_seconds 30

    if test "$argv[1]" = --no-lid
        __stayawake_log 'Lid-close sleep: skipped (--no-lid)'
    else if __stayawake_block_lid_sleep
        __stayawake_log "Lid-close sleep: blocked (SleepDisabled=$(pmset -g | awk '/SleepDisabled/{print $2}'))"
    else
        __stayawake_log 'Lid-close sleep: authorization failed, idle sleep still blocked'
    end

    __stayawake_log 'Idle sleep: blocked (screen may still go dark)'
    __stayawake_log "Monitoring, Ctrl-C to stop. Thresholds $__stayawake_warn%/$__stayawake_critical%, polling every "$poll_seconds"s."

    while true
        __stayawake_check_battery
        __stayawake_check_thermal
        sleep $poll_seconds
    end
end

function __stayawake_log
    printf '%s  %s\n' (date '+%H:%M:%S') $argv[1]
end

function __stayawake_play
    for i in (seq $argv[2])
        afplay /System/Library/Sounds/$argv[1].aiff 2>/dev/null
    end
end

# Foundation's thermalState is the only public heat signal on Apple Silicon;
# pmset -g therm and sysctl report nothing there. JXA bridges to it in ~30ms.
function __stayawake_thermal_state
    osascript -l JavaScript \
        -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState' 2>/dev/null
    or echo 0
end

function __stayawake_thermal_label
    switch $argv[1]
        case 0
            echo 'nominal'
        case 1
            echo 'fair'
        case 2
            echo 'serious (throttling)'
        case 3
            echo 'critical'
        case '*'
            echo 'unknown'
    end
end

# Lid close uses a different sleep path than idle sleep and ignores power
# assertions, so it needs the root-only disablesleep flag. A root watchdog
# restores it once this shell dies — even on kill -9.
# It always restores 0, never the value read at launch: the flag is persisted to
# /Library/Preferences/com.apple.PowerManagement.plist, so a power cut — which
# kills the watchdog too — leaves it set across reboots, and replaying that value
# back would make the leak permanent.
function __stayawake_block_lid_sleep
    if test "$(pmset -g | awk '/SleepDisabled/{print $2}')" = 1
        __stayawake_log 'Warning: SleepDisabled was already 1 at launch, likely left over from an unclean exit'
    end
    sudo sh -c "pmset -a disablesleep 1; \
        (while kill -0 $fish_pid 2>/dev/null; do sleep 2; done; \
         pmset -a disablesleep 0) </dev/null >/dev/null 2>&1 &"
end

function __stayawake_check_battery
    set -l batt (pmset -g batt | string collect)
    if string match -q "*'AC Power'*" -- $batt
        set -g __stayawake_last_battery 0
        return
    end

    set -l percent (string match -r '[0-9]{1,3}(?=%)' -- $batt)
    test -n "$percent"; or return

    set -l now (date +%s)
    if test $percent -le $__stayawake_warn
        test (math $now - $__stayawake_last_battery) -lt $__stayawake_repeat; and return
        set -g __stayawake_last_battery $now
        if test $percent -le $__stayawake_critical
            __stayawake_log "⚠︎ Battery $percent% — critically low"
            __stayawake_play Sosumi 3
        else
            __stayawake_log "⚠︎ Battery $percent% — low"
            __stayawake_play Submarine 1
        end
    else if test $percent -ge $__stayawake_clear
        set -g __stayawake_last_battery 0
    end
end

function __stayawake_check_thermal
    set -l state (__stayawake_thermal_state)
    if test $state -ge 2
        set -l now (date +%s)
        test (math $now - $__stayawake_last_thermal) -lt $__stayawake_repeat; and return
        set -g __stayawake_last_thermal $now
        __stayawake_log "⚠︎ Thermal state: $(__stayawake_thermal_label $state)"
        __stayawake_play Basso 2
    else
        set -g __stayawake_last_thermal 0
    end
end
