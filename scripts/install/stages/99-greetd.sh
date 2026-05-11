#!/usr/bin/env bash
# Stage 99 - Optional graphical login.
#
# Installs greetd + ReGreet on cage and writes /etc/greetd/config.toml.
# This stage is intentionally excluded from --all.
#
# Verified against: Arch greetd package and greetd/ReGreet layout
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 99 - optional greetd/ReGreet"

if ! confirm "Enable graphical login with greetd/ReGreet?"; then
    log_warn "Stage 99 aborted by user"
    exit 130
fi

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

pacman_install greetd greetd-regreet cage

install_system_template() {
    local src="$1" dest="$2" mode="${3:-0644}"

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
}

install_system_template "$ROOT/system/greetd.toml" /etc/greetd/config.toml 0644
install_system_template "$ROOT/system/regreet.toml" /etc/greetd/regreet.toml 0644

log_warn "comment the exec-sway block in ~/.zprofile before rebooting into greetd"
run sudo systemctl disable getty@tty1.service
run sudo systemctl enable greetd.service

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 99 dry-run complete"
    exit 0
fi

errs=0
for cmd in regreet cage; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "command present: $cmd"
    else
        log_error "command missing: $cmd"
        (( ++errs ))
    fi
done

if systemctl is-enabled greetd.service >/dev/null 2>&1; then
    log_ok "greetd.service enabled"
else
    log_error "greetd.service is not enabled"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 99 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 99 complete - greetd/ReGreet enabled"
