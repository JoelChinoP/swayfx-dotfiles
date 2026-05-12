#!/usr/bin/env bash
# Stage 09 - Lock, power menu and zram.
#
# Installs zram-generator, swaylock-effects and wlogout. Writes the
# zram-generator and zram sysctl system templates with backup.
#
# Verified against: Arch zram-generator and swaylock-effects usage
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 09 - lock, power and zram"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

pacman_install zram-generator

ensure_wlogout_pgp_key() {
    local key="F4FDB18A9937358364B276E9E25D679AF73C6D2F"

    if gpg --list-keys "$key" >/dev/null 2>&1; then
        log_ok "wlogout PGP key already present"
        return 0
    fi

    if ! command -v curl >/dev/null 2>&1; then
        log_warn "curl missing; paru may need to import the wlogout PGP key interactively"
        return 0
    fi

    log_info "importing wlogout upstream PGP key from GitHub"
    if ! curl -fsSL https://github.com/ArtsyMacaw.gpg | gpg --import; then
        log_warn "could not import wlogout PGP key; paru will attempt its normal key import"
    fi
}

ensure_wlogout_pgp_key
paru_install swaylock-effects wlogout

install_system_template() {
    local src="$1" dest="$2" mode="${3:-0644}"

    if [[ ! -f "$src" ]]; then
        log_fatal "template missing: $src"
        exit 1
    fi

    if (( DRY_RUN )); then
        log_info "would install $src -> $dest"
        return 0
    fi

    if [[ -e "$dest" ]] && ! cmp -s "$src" "$dest"; then
        local ts backup_path
        ts="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"
        backup_path="$BACKUP_DIR/$ts${dest}"
        mkdir -p "$(dirname "$backup_path")"
        sudo cp -a "$dest" "$backup_path"
        log_warn "backed up $dest to $backup_path"
    fi

    sudo install -Dm "$mode" "$src" "$dest"
    log_ok "installed $dest"
}

install_system_template "$ROOT/system/zram-generator.conf" /etc/systemd/zram-generator.conf 0644
install_system_template "$ROOT/system/sysctl.d/99-swayfx-zram.conf" /etc/sysctl.d/99-swayfx-zram.conf 0644

run sudo systemctl daemon-reload
run sudo sysctl --load /etc/sysctl.d/99-swayfx-zram.conf
run sudo systemctl restart systemd-zram-setup@zram0.service

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 09 dry-run complete"
    exit 0
fi

errs=0

if swaylock --help 2>&1 | grep -q screenshots; then
    log_ok "swaylock-effects binary responds"
else
    log_error "swaylock-effects features not detected in swaylock --help"
    (( ++errs ))
fi

if command -v wlogout >/dev/null 2>&1; then
    log_ok "wlogout is installed"
else
    log_error "wlogout is not on PATH"
    (( ++errs ))
fi

if zramctl | grep -q zram0; then
    log_ok "zram0 is active"
else
    log_error "zram0 is not active"
    (( ++errs ))
fi

if [[ "$(sysctl -n vm.swappiness 2>/dev/null)" == "180" ]]; then
    log_ok "vm.swappiness is 180"
else
    log_error "vm.swappiness is not 180"
    (( ++errs ))
fi

if [[ "$(sysctl -n vm.page-cluster 2>/dev/null)" == "0" ]]; then
    log_ok "vm.page-cluster is 0"
else
    log_error "vm.page-cluster is not 0"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 09 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 09 complete - lock, power menu and zram are ready"
