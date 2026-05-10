#!/usr/bin/env bash
# Package-management wrappers. Sourced by stage scripts after common.sh.
#
# Verified against: pacman(8), paru(8), AUR install workflow
# Reviewed: 2026-05-10

# Install one or more packages from official repos. Idempotent.
pacman_install() {
    (( $# > 0 )) || { log_warn "pacman_install: nothing to install"; return 0; }
    log_info "pacman -S --needed $*"
    run sudo pacman -S --needed --noconfirm "$@"
}

# Install one or more packages from AUR via paru. Idempotent.
paru_install() {
    (( $# > 0 )) || { log_warn "paru_install: nothing to install"; return 0; }
    require paru
    log_info "paru -S --needed $*"
    run paru -S --needed --noconfirm "$@"
}

# Install AUR packages but log_warn on failure instead of failing the
# stage. Use for genuinely optional things (asusctl, satty).
paru_install_optional() {
    (( $# > 0 )) || return 0
    require paru
    log_info "paru -S --needed (optional) $*"
    if ! run paru -S --needed --noconfirm "$@"; then
        log_warn "optional AUR package(s) failed to install: $*"
        return 0
    fi
}

# Bootstrap paru by cloning from AUR and running makepkg. Requires that
# git, base-devel and a working sudo are already in place. No-op if paru
# is already on PATH.
bootstrap_paru() {
    if command -v paru >/dev/null 2>&1; then
        log_ok "paru already installed"
        return 0
    fi
    require git
    require makepkg

    if (( DRY_RUN )); then
        printf '%sDRY:%s clone https://aur.archlinux.org/paru.git and `makepkg -si`\n' \
            "$C_DIM" "$C_RESET" >&2
        return 0
    fi

    log_info "bootstrapping paru from AUR"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN

    git clone --depth=1 https://aur.archlinux.org/paru.git "$tmp/paru"
    ( cd "$tmp/paru" && makepkg -si --noconfirm )

    command -v paru >/dev/null 2>&1
}
