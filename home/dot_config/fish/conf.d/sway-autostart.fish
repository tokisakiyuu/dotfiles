# Auto-start sway on tty1 login (headless framebuffer use).
# Lives in conf.d/ so fish auto-sources it. Bails out gracefully when:
#   - not a login shell        (e.g. nested fish, scripts)
#   - not on physical tty1     (SSH, other VTs)
#   - WAYLAND_DISPLAY already set (already in a Wayland session)
#   - sway isn't installed     (this config syncs across machines)
if status is-login
    if test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = "1"; and command -q sway
        set -x LIBSEAT_BACKEND seatd
        exec sway 2> ~/.sway.log
    end
end
