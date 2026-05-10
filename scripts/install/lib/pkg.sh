#!/usr/bin/env bash
# Package-management wrappers. Sourced by stage scripts after common.sh.
#
# Verified against: pacman(8), paru(8), AUR install workflow
# Reviewed: 2026-05-10

# Install one or more packages from official repos. Idempotent.
pacman_install() {
    (( $# > 0 )) || { log_warn "pacman_install: nothing to install"; return 0; }
    local IFS=' '
    log_info "pacman -S --needed $*"
    run sudo pacman -S --needed --noconfirm "$@"
}

# Install one or more packages from AUR via paru. Idempotent.
paru_install() {
    (( $# > 0 )) || { log_warn "paru_install: nothing to install"; return 0; }
    require paru
    local IFS=' '
    log_info "paru -S --needed $*"
    run paru -S --needed --noconfirm "$@"
}

# Install AUR packages but log_warn on failure instead of failing the
# stage. Use for genuinely optional things (asusctl, satty).
paru_install_optional() {
    (( $# > 0 )) || return 0
    require paru
    local IFS=' '
    log_info "paru -S --needed (optional) $*"
    if ! run paru -S --needed --noconfirm "$@"; then
        log_warn "optional AUR package(s) failed to install: $*"
        return 0
    fi
}

# Bootstrap paru. Tries paru-bin first (binary, ~5 MB, instant install).
# If the binary cannot load (ABI mismatch with current libalpm), falls
# back to a source build of `paru` (rust toolchain, ~500 MB transitive
# deps, ~5–30 min on real hardware).
#
# Build dirs live under $HOME/.cache because /tmp is often tmpfs with a
# 1/2-RAM limit that cannot fit a makepkg work tree (especially the
# rust source build).
#
# Override the choice with `PARU_VARIANT=paru` to skip the -bin attempt.
_paru_works() { command -v paru >/dev/null 2>&1 && paru --version &>/dev/null; }

bootstrap_paru() {
    if _paru_works; then
        log_ok "paru already installed and working"
        return 0
    fi
    require git
    require makepkg

    if (( DRY_RUN )); then
        printf '%sDRY:%s install paru via AUR (paru-bin → fallback paru source)\n' \
            "$C_DIM" "$C_RESET" >&2
        return 0
    fi

    local build_root="$HOME/.cache/swayfx-dotfiles/build"
    mkdir -p "$build_root"

    _try_aur_pkg() {
        local pkg="$1"
        local tmp
        tmp="$(mktemp -d -p "$build_root")"
        log_info "bootstrapping $pkg from AUR (build dir: $tmp)"
        if ! git clone --depth=1 "https://aur.archlinux.org/$pkg.git" "$tmp/$pkg"; then
            log_warn "git clone of $pkg failed"
            rm -rf "$tmp"; return 1
        fi
        # TMPDIR keeps cargo/llvm intermediates out of tmpfs.
        if ! ( cd "$tmp/$pkg" && TMPDIR="$build_root" makepkg -si --noconfirm ); then
            log_warn "makepkg for $pkg failed"
            rm -rf "$tmp"; return 1
        fi
        rm -rf "$tmp"
        return 0
    }

    local variant="${PARU_VARIANT:-paru-bin}"

    # First attempt
    if _try_aur_pkg "$variant" && _paru_works; then
        return 0
    fi

    # If -bin installed but does not run (libalpm ABI mismatch), remove it
    # so the source build is the sole provider.
    if [[ "$variant" == "paru-bin" ]] && pacman -Q paru-bin &>/dev/null; then
        log_warn "paru-bin installed but does not run (likely libalpm ABI mismatch); switching to source build"
        sudo pacman -Rns --noconfirm paru-bin paru-bin-debug 2>/dev/null || \
            sudo pacman -Rns --noconfirm paru-bin              2>/dev/null || true
    fi

    # Fallback: source build (only attempted if -bin was the first try).
    if [[ "$variant" == "paru-bin" ]]; then
        if _try_aur_pkg paru && _paru_works; then
            return 0
        fi
    fi

    log_fatal "could not install a working paru"
    return 1
}
