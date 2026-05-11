#!/usr/bin/env bash
# Stage 03 - SwayFX.
#
# Installs SwayFX from AUR. The package provides the `sway` binary and
# conflicts with vanilla Sway, so paru handles the package swap.
#
# Verified against: .claude/PLAN.md §2 stage 03, .claude/REFERENCES.md §1
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 03 - SwayFX"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

require paru
log_info "paru -S --needed --noconfirm --useask --noprovides swayfx"
run paru -S --needed --noconfirm --useask --noprovides swayfx

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 03 dry-run complete"
    exit 0
fi

errs=0

if pacman -Q swayfx >/dev/null 2>&1; then
    log_ok "package present: swayfx"
else
    log_error "package missing: swayfx"
    (( ++errs ))
fi

if command -v sway >/dev/null 2>&1; then
    log_ok "sway binary present: $(command -v sway)"
else
    log_error "sway binary missing after swayfx install"
    (( ++errs ))
fi

if swaymsg -t get_version 2>/dev/null | grep -qi swayfx; then
    log_ok "running compositor reports SwayFX"
else
    log_warn "no running SwayFX IPC detected; package validation is being used instead"
fi

if [[ -f /usr/share/wayland-sessions/sway.desktop ]] \
   || [[ -f /usr/share/wayland-sessions/swayfx.desktop ]]; then
    log_ok "Wayland session file present"
else
    log_error "missing Sway/SwayFX Wayland session file"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 03 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 03 complete - SwayFX is installed"
