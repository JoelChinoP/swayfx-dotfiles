# ~/.zprofile — read by zsh login shells, after .zshenv.
# Auto-starts SwayFX on TTY1.
#
# Verified against: ArchWiki "Sway" → "Autostart on login", sway(5)
# Reviewed: 2026-05-10

# Pull in /etc/profile-style system config (PATH adjustments, etc.).
emulate sh -c 'source /etc/profile' 2>/dev/null || true

# Start SwayFX on TTY1 only. We do *not* want this to fire when the
# user logs in via SSH or on TTY2-6 to debug.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = "1" ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export XDG_SESSION_DESKTOP=sway

    # Wayland-friendly defaults that some apps need.
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM="wayland;xcb"
    export SDL_VIDEODRIVER=wayland
    export CLUTTER_BACKEND=wayland
    export _JAVA_AWT_WM_NONREPARENTING=1

    # AMD VAAPI driver hint (Vega 8 → radeonsi).
    export LIBVA_DRIVER_NAME=radeonsi
    export VDPAU_DRIVER=radeonsi

    # Cursor (matches what stage 08 sets via gsettings).
    export XCURSOR_THEME=Bibata-Modern-Classic
    export XCURSOR_SIZE=24

    # NOTE: until stage 03 installs SwayFX, `sway` does not exist and
    # this exec will fail back to the prompt. Comment the next line if
    # you need to log in to TTY1 without launching the compositor.
    exec sway
fi
