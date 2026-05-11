#!/usr/bin/env bash
# Stage 07 - Applications.
#
# Installs daily GUI apps, terminal utilities, archive backends, Brave
# from AUR, and Mission Center from official repos.
#
# Verified against: current Arch package metadata
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 07 - applications"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

APP_PKGS=(
    nautilus loupe papers gnome-text-editor gnome-calculator
    file-roller mpv
    mission-center btop tree htop
    unzip zip p7zip tar
)
pacman_install "${APP_PKGS[@]}"

paru_install brave-bin

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 07 dry-run complete"
    exit 0
fi

errs=0

for cmd in nautilus loupe papers gnome-text-editor gnome-calculator file-roller mpv btop htop 7z brave missioncenter; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "command present: $cmd"
    else
        log_error "command missing: $cmd"
        (( ++errs ))
    fi
done

if (( errs > 0 )); then
    log_fatal "Stage 07 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 07 complete - applications are installed"
