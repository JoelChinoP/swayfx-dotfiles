#!/usr/bin/env bash
# Stage 07 - Applications.
#
# Installs daily GUI apps, terminal utilities, archive backends, Mermaid
# CLI, Brave Origin release from AUR, and Mission Center from official repos.
#
# Verified against: https://brave.com/origin/linux/ and current Arch/AUR package metadata
# Reviewed: 2026-07-07

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
    mermaid-cli
)
pacman_install "${APP_PKGS[@]}"

STANDARD_BRAVE_PKGS=(
    brave-bin
    brave-beta-bin
    brave-nightly-bin
    brave-browser
)
installed_standard_brave=()
declare -A seen_standard_brave=()
for pkg in "${STANDARD_BRAVE_PKGS[@]}"; do
    actual_pkg="$(pacman -Qq "$pkg" 2>/dev/null || true)"
    if [[ -n "$actual_pkg" && -z "${seen_standard_brave[$actual_pkg]:-}" ]]; then
        installed_standard_brave+=("$actual_pkg")
        seen_standard_brave[$actual_pkg]=1
    fi
done

if (( ${#installed_standard_brave[@]} > 0 )); then
    log_warn "standard Brave package(s) installed: ${installed_standard_brave[*]}"
    if confirm "Remove standard Brave before installing Brave Origin?"; then
        require paru
        run paru -Rns --noconfirm "${installed_standard_brave[@]}"
    else
        log_fatal "standard Brave must be removed before this stage can continue"
        exit 1
    fi
fi

OLD_BRAVE_PATHS=(
    "$HOME/.config/BraveSoftware/Brave-Browser"
    "$HOME/.cache/BraveSoftware/Brave-Browser"
    "$HOME/.config/brave-flags.conf"
)
shopt -s nullglob
OLD_BRAVE_PATHS+=("$HOME/.local/share/applications"/brave-*.desktop)
shopt -u nullglob

existing_old_brave_paths=()
for path in "${OLD_BRAVE_PATHS[@]}"; do
    [[ -e "$path" || -L "$path" ]] && existing_old_brave_paths+=("$path")
done

if (( ${#existing_old_brave_paths[@]} > 0 )); then
    log_warn "old standard Brave profile/cache/launcher data found"
    if confirm "Delete old standard Brave data for a clean Origin install?"; then
        for path in "${existing_old_brave_paths[@]}"; do
            run rm -rf -- "$path"
        done
    else
        log_warn "old standard Brave data left in place"
    fi
fi

migrate_brave_origin_path() {
    local old_path="$1" new_path="$2"

    if [[ ! -e "$old_path" && ! -L "$old_path" ]]; then
        return 0
    fi

    if [[ -e "$new_path" || -L "$new_path" ]]; then
        log_warn "not migrating $old_path; destination already exists: $new_path"
        return 0
    fi

    run mkdir -p "$(dirname "$new_path")"
    run mv -- "$old_path" "$new_path"
    log_ok "migrated $old_path -> $new_path"
}

paru_install brave-origin-bin

if pgrep -u "$USER" -f 'brave-origin|Brave-Origin' >/dev/null 2>&1; then
    log_fatal "close Brave Origin/Beta before migrating browser profile data"
    exit 1
fi

migrate_brave_origin_path \
    "$HOME/.config/BraveSoftware/Brave-Origin-Beta" \
    "$HOME/.config/BraveSoftware/Brave-Origin"
migrate_brave_origin_path \
    "$HOME/.cache/BraveSoftware/Brave-Origin-Beta" \
    "$HOME/.cache/BraveSoftware/Brave-Origin"
migrate_brave_origin_path \
    "$HOME/.config/BraveSoftware/Brave-Origin-Beta-Dev" \
    "$HOME/.config/BraveSoftware/Brave-Origin-Dev"

if command -v xdg-mime >/dev/null 2>&1; then
    log_info "setting Brave Origin release as default browser"
    for mime in \
        text/html \
        x-scheme-handler/http \
        x-scheme-handler/https \
        x-scheme-handler/about \
        x-scheme-handler/unknown; do
        run xdg-mime default brave-origin.desktop "$mime"
    done
else
    log_warn "xdg-mime missing; default browser associations were not updated"
fi

PREVIEW_BRAVE_PKGS=(
    brave-origin-beta-bin
    brave-origin-nightly-bin
)
installed_preview_brave=()
for pkg in "${PREVIEW_BRAVE_PKGS[@]}"; do
    pacman -Qq "$pkg" >/dev/null 2>&1 && installed_preview_brave+=("$pkg")
done

if (( ${#installed_preview_brave[@]} > 0 )); then
    log_warn "Brave Origin preview package(s) installed: ${installed_preview_brave[*]}"
    if confirm "Remove Brave Origin preview packages after installing release?"; then
        require paru
        run paru -Rns --noconfirm "${installed_preview_brave[@]}"
    else
        log_warn "Brave Origin preview packages left installed"
    fi
fi

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 07 dry-run complete"
    exit 0
fi

errs=0

for cmd in nautilus loupe papers gnome-text-editor gnome-calculator file-roller mpv btop htop 7z mmdc brave-origin missioncenter; do
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
