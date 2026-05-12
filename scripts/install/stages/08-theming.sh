#!/usr/bin/env bash
# Stage 08 - Theming.
#
# Installs GTK/Qt dark-theme dependencies, cursor, icons and fonts.
# Applies global dark settings through gsettings.
#
# Verified against: Arch GTK, Qt, fontconfig and Starship/Waybar needs
# Reviewed: 2026-05-12

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 08 - dark theming"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

THEME_PKGS=(
    adw-gtk-theme papirus-icon-theme
    qt6ct kvantum nwg-look
    ttf-firacode-nerd ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji inter-font
)
pacman_install "${THEME_PKGS[@]}"

paru_install bibata-cursor-theme

set_gsetting() {
    local schema="$1" key="$2" value="$3"
    if (( DRY_RUN )); then
        log_info "would set gsettings $schema $key $value"
        return 0
    fi

    if gsettings writable "$schema" "$key" >/dev/null 2>&1; then
        gsettings set "$schema" "$key" "$value"
    elif command -v dbus-run-session >/dev/null 2>&1; then
        dbus-run-session gsettings set "$schema" "$key" "$value"
    else
        log_warn "cannot set gsettings $schema $key; no writable session bus"
    fi
}

set_gsetting org.gnome.desktop.interface color-scheme "'prefer-dark'"
set_gsetting org.gnome.desktop.interface gtk-theme "'adw-gtk3-dark'"
set_gsetting org.gnome.desktop.interface icon-theme "'Papirus-Dark'"
set_gsetting org.gnome.desktop.interface cursor-theme "'Bibata-Modern-Classic'"
set_gsetting org.gnome.desktop.interface font-name "'Inter 11'"
set_gsetting org.gnome.desktop.interface monospace-font-name "'FiraCode Nerd Font Mono 10'"

run fc-cache -fv

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 08 dry-run complete"
    exit 0
fi

errs=0

if [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" == "'prefer-dark'" ]]; then
    log_ok "GNOME color-scheme is prefer-dark"
else
    log_error "GNOME color-scheme is not prefer-dark"
    (( ++errs ))
fi

if fc-match -f '%{family}\n' 'FiraCode Nerd Font Mono' | grep -qi 'FiraCode.*Nerd'; then
    log_ok "FiraCode Nerd Font registered"
else
    log_error "FiraCode Nerd Font missing"
    (( ++errs ))
fi

if fc-match -f '%{family}\n' 'JetBrainsMono Nerd Font' | grep -qi 'JetBrains.*Nerd'; then
    log_ok "JetBrainsMono Nerd Font registered"
else
    log_error "JetBrainsMono Nerd Font missing"
    (( ++errs ))
fi

if fc-match -f '%{family}\n' 'Inter' | grep -qi 'Inter'; then
    log_ok "Inter font registered"
else
    log_error "Inter font missing"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 08 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 08 complete - dark theme dependencies are ready"
