#!/usr/bin/env bash
# Stage 05 - Bars.
#
# Installs Waybar and icon fonts. The actual top/bottom configs are
# applied in stage 10 with Stow.
#
# Verified against: waybar(5), waybar-wlr-taskbar(5)
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 05 - waybar bars"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

pacman_install waybar otf-font-awesome

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 05 dry-run complete"
    exit 0
fi

errs=0

if command -v waybar >/dev/null 2>&1; then
    log_ok "waybar is installed"
else
    log_error "waybar is not on PATH"
    (( ++errs ))
fi

if pacman -Q waybar otf-font-awesome >/dev/null 2>&1; then
    log_ok "waybar and otf-font-awesome packages present"
else
    log_error "missing waybar or otf-font-awesome package"
    (( ++errs ))
fi

if waybar --help 2>&1 | grep -q -- '--config'; then
    log_ok "waybar supports explicit --config"
else
    log_error "waybar --help did not expose --config"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 05 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 05 complete - Waybar is ready for stage 10 configs"
