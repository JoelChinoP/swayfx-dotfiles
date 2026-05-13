#!/usr/bin/env bash
# Stage 10 - Final dotfile deployment.
#
# Applies all Stow packages, refreshes user dirs and font cache, then
# runs the automated post-install checks.
#
# Verified against: GNU Stow manual and .claude/PLAN.md stage 10
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"

log_info "Stage 10 - final Stow deployment"

export BACKUP_TS="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"

PKGS=(
    colors
    environment
    gtk
    zsh
    starship
    sway
    waybar
    ghostty
    fuzzel
    mako
    swaylock
    wlogout
    gammastep
    mpv
    brave
    scripts
)

for pkg in "${PKGS[@]}"; do
    stow_package "$pkg"
done

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    run xdg-user-dirs-update
else
    log_warn "xdg-user-dirs-update missing; stage 02 should install xdg-user-dirs"
fi

if command -v fc-cache >/dev/null 2>&1; then
    run fc-cache -fv
else
    log_warn "fc-cache missing"
fi

if (( DRY_RUN )); then
    log_warn "skipping final checks (dry-run)"
    log_ok "Stage 10 dry-run complete"
    exit 0
fi

bash "$ROOT/scripts/install/lib/checks.sh"

log_ok "Stage 10 complete - dotfiles deployed"
log_warn "Log out and back into TTY1. Then run CHECK_LIVE=1 $ROOT/scripts/install/lib/checks.sh inside SwayFX."
