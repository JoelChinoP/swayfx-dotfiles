#!/usr/bin/env bash
# Stage 04 - Session helpers.
#
# Installs the launcher, notification daemon, IPC helper library, and XDG
# portals needed for a usable Wayland session. Dotfiles still remain
# deferred to stage 10.
#
# Verified against: .claude/PLAN.md §2 stage 04 and Arch python-i3ipc
# Reviewed: 2026-05-14

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 04 - session helpers"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

SESSION_PKGS=(
    fuzzel mako
    python-i3ipc
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
)
pacman_install "${SESSION_PKGS[@]}"

write_portals_conf() {
    local portal_dir="$HOME/.config/xdg-desktop-portal"
    local portal_file="$portal_dir/portals.conf"

    if (( DRY_RUN )); then
        log_info "would write $portal_file"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    cat > "$tmp" <<'EOF'
# Verified against: man portals.conf(5)
# Reviewed: 2026-05-11

[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
EOF

    mkdir -p "$portal_dir"

    if [[ -e "$portal_file" ]] && ! cmp -s "$tmp" "$portal_file"; then
        local ts backup_path
        ts="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"
        backup_path="$BACKUP_DIR/$ts/xdg-desktop-portal/portals.conf"
        mkdir -p "$(dirname "$backup_path")"
        mv "$portal_file" "$backup_path"
        log_warn "existing portals.conf backed up to $backup_path"
    fi

    install -m 0644 "$tmp" "$portal_file"
    rm -f "$tmp"
    log_ok "wrote $portal_file"
}

write_portals_conf

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 04 dry-run complete"
    exit 0
fi

errs=0

if command -v fuzzel >/dev/null 2>&1; then
    log_ok "fuzzel is installed"
else
    log_error "fuzzel is not on PATH"
    (( ++errs ))
fi

if command -v mako >/dev/null 2>&1; then
    log_ok "mako is installed"
else
    log_error "mako is not on PATH"
    (( ++errs ))
fi

for pkg in xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk; do
    if pkg_installed "$pkg"; then
        log_ok "package present: $pkg"
    else
        log_error "package missing: $pkg"
        (( ++errs ))
    fi
done

if python -c 'import i3ipc' >/dev/null 2>&1; then
    log_ok "python i3ipc module is installed"
else
    log_error "python i3ipc module is not importable"
    (( ++errs ))
fi

if [[ -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
    log_ok "polkit-gnome authentication agent present"
else
    log_error "polkit-gnome authentication agent missing (stage 02 should install it)"
    (( ++errs ))
fi

if [[ -f "$HOME/.config/xdg-desktop-portal/portals.conf" ]] \
   && grep -q '^org.freedesktop.impl.portal.ScreenCast=wlr$' "$HOME/.config/xdg-desktop-portal/portals.conf"; then
    log_ok "xdg-desktop-portal preference file is present"
else
    log_error "xdg-desktop-portal preference file missing or incomplete"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 04 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 04 complete - launcher, notifications, and portals are ready"
