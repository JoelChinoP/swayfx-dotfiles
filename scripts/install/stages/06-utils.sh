#!/usr/bin/env bash
# Stage 06 - Session utilities.
#
# Installs clipboard, screenshots, brightness, network, bluetooth,
# idle, notifications helper, JSON helper, and optional ASUS tooling.
#
# Verified against: .claude/PLAN.md stage 06 and current Arch packages
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 06 - utilities"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

UTIL_PKGS=(
    wl-clipboard cliphist
    grim slurp satty
    brightnessctl gammastep
    wdisplays pavucontrol playerctl
    networkmanager network-manager-applet
    bluez bluez-utils blueman
    swayidle libnotify
    jq ufw
)
pacman_install "${UTIL_PKGS[@]}"

log_info "enabling NetworkManager and bluetooth"
run sudo systemctl enable --now NetworkManager.service bluetooth.service

if command -v paru >/dev/null 2>&1 || (( DRY_RUN )); then
    paru_install nmgui-bin
    paru_install_optional asusctl
else
    log_warn "paru missing; skipping AUR packages (nmgui, asusctl)"
fi

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 06 dry-run complete"
    exit 0
fi

errs=0

for cmd in wl-copy cliphist grim slurp brightnessctl gammastep wdisplays pavucontrol playerctl nmcli bluetoothctl notify-send jq ufw; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "command present: $cmd"
    else
        log_error "command missing: $cmd"
        (( ++errs ))
    fi
done

if nmcli -t -f STATE general 2>/dev/null | grep -qE 'connected|disconnected|connecting'; then
    log_ok "NetworkManager responds to nmcli"
else
    log_error "nmcli did not report NetworkManager state"
    (( ++errs ))
fi

if brightnessctl get >/dev/null 2>&1; then
    log_ok "brightnessctl can read brightness"
else
    log_warn "brightnessctl could not read brightness; this may be VM or permissions"
fi

if systemctl is-enabled bluetooth.service >/dev/null 2>&1; then
    log_ok "bluetooth.service enabled"
else
    log_warn "bluetooth.service not enabled; skip if hardware has no bluetooth"
fi

if (( errs > 0 )); then
    log_fatal "Stage 06 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 06 complete - utilities are installed"
