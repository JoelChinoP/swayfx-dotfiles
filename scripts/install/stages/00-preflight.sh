#!/usr/bin/env bash
# Stage 00 - Pre-flight.
#
# Validates the host premises, repairs missing official bootstrap
# packages needed by the installer, removes rejected power-policy daemons
# when confirmed, bootstraps the AUR helper if missing, and prepares
# state/backup directories.
#
# This stage still does not install graphical desktop packages. It only
# repairs official packages that the installer itself needs.
#
# Verified against: .claude/PLAN.md stage 00
# Reviewed: 2026-05-12

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 00 - preflight"

REPAIRABLE_BASE_PKGS=(
    linux-firmware sof-firmware amd-ucode
    networkmanager git
    zsh starship stow
    lm_sensors jq
    curl wget openssh
    unzip zip p7zip
)

REQUIRED_PKGS=(sudo "${REPAIRABLE_BASE_PKGS[@]}")
REJECTED_POWER_PKGS=(power-profiles-daemon tlp auto-cpufreq ryzenadj)
BASE_DEVEL_COMMANDS=(makepkg make gcc fakeroot pkgconf)

base_devel_ready() {
    local cmd
    for cmd in "${BASE_DEVEL_COMMANDS[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
    return 0
}

check_network_reachable() {
    local mode="${1:-warn}"

    if command -v ping >/dev/null 2>&1 && ping -c 1 -W 3 archlinux.org &>/dev/null; then
        log_ok "internet reachable (ping archlinux.org)"
        return 0
    fi

    if command -v curl >/dev/null 2>&1 && curl -fsI --max-time 5 https://archlinux.org &>/dev/null; then
        log_ok "internet reachable (curl archlinux.org)"
        return 0
    fi

    if command -v nm-online >/dev/null 2>&1 && nm-online -t 5 &>/dev/null; then
        log_warn "ping/curl probe failed but nm-online reports a connection - continuing"
        return 0
    fi

    if [[ "$mode" == "fatal" ]]; then
        log_fatal "no internet connection"
        exit 1
    fi

    log_warn "could not verify internet before package repair; pacman will be the connectivity test"
}

install_missing_base_packages() {
    local missing=()
    local p

    for p in "${REPAIRABLE_BASE_PKGS[@]}"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if ! base_devel_ready; then
        missing+=(base-devel)
    fi

    if (( ${#missing[@]} == 0 )); then
        log_ok "all repairable base packages present"
        return 0
    fi

    local joined
    joined="$(IFS=' '; echo "${missing[*]}")"
    log_warn "missing base installer packages: $joined"
    pacman_install "${missing[@]}"

    if (( DRY_RUN )); then
        log_warn "dry-run: skipping post-repair package validation"
        return 0
    fi

    require_pkgs "${REQUIRED_PKGS[@]}" || {
        log_fatal "base package repair did not complete; inspect pacman output and re-run"
        exit 1
    }
    if ! base_devel_ready; then
        log_fatal "base-devel toolchain is still incomplete after repair"
        exit 1
    fi
    log_ok "base installer packages repaired"
}

remove_rejected_power_policy() {
    local installed=()
    local p

    for p in "${REJECTED_POWER_PKGS[@]}"; do
        pkg_installed "$p" && installed+=("$p")
    done

    if (( ${#installed[@]} == 0 )); then
        log_ok "no rejected power policy packages installed"
        return 0
    fi

    local joined
    joined="$(IFS=' '; echo "${installed[*]}")"
    log_warn "rejected power policy packages installed: $joined"

    if (( DRY_RUN )); then
        run sudo pacman -Rns --noconfirm "${installed[@]}"
        return 0
    fi

    if ! confirm "Remove rejected power policy packages now?"; then
        log_fatal "remove $joined before continuing; the project uses cpupower as the only CPU policy layer"
        exit 1
    fi

    run sudo pacman -Rns --noconfirm "${installed[@]}"

    for p in "${installed[@]}"; do
        if pkg_installed "$p"; then
            log_fatal "package still installed after removal attempt: $p"
            exit 1
        fi
    done
    log_ok "removed rejected power policy packages"
}

ensure_networkmanager() {
    if ! systemctl is-enabled NetworkManager.service &>/dev/null; then
        log_warn "NetworkManager.service is not enabled - enabling"
        run sudo systemctl enable NetworkManager.service
    fi

    if ! systemctl is-active NetworkManager.service &>/dev/null; then
        log_warn "NetworkManager.service is not active - starting"
        run sudo systemctl start NetworkManager.service
    fi

    if (( DRY_RUN )); then
        log_warn "dry-run: skipping NetworkManager post-validation"
        return 0
    fi

    if ! systemctl is-enabled NetworkManager.service &>/dev/null; then
        log_fatal "NetworkManager.service is not enabled"
        exit 1
    fi
    if ! systemctl is-active NetworkManager.service &>/dev/null; then
        log_fatal "NetworkManager.service is not active"
        exit 1
    fi
    log_ok "NetworkManager enabled and active"
}

# 1. Distro identity
if [[ ! -f /etc/arch-release ]]; then
    if (( DRY_RUN )); then
        log_warn "this is not an Arch system; skipping host preflight checks in dry-run"
        log_ok "Stage 00 dry-run complete"
        exit 0
    fi
    log_fatal "this is not an Arch system"
    exit 1
fi
log_ok "Arch detected"

# 2. Target user and architecture
if (( EUID == 0 )); then
    log_fatal "run the installer as the target user with sudo, not as root"
    exit 1
fi

arch="$(uname -m)"
[[ "$arch" == "x86_64" ]] || { log_fatal "unsupported architecture: $arch"; exit 1; }
log_ok "architecture: x86_64"

# 3. UEFI (warn-only)
if [[ -d /sys/firmware/efi/efivars ]]; then
    log_ok "UEFI firmware detected"
else
    log_warn "system is not UEFI - bootloader assumptions in PLAN may not hold"
fi

# 4. Sudo is the non-repairable bootstrap requirement.
if ! command -v sudo >/dev/null 2>&1 || ! pkg_installed sudo; then
    log_fatal "sudo is required before stage 00 can repair packages; install sudo and add '$USER' to wheel"
    exit 1
fi

log_info "verifying sudo (may prompt for password)"
if ! sudo true; then
    log_fatal "sudo failed (user may not be in wheel, or password rejected)"
    exit 1
fi
log_ok "sudo verified"

# 5. Connectivity and time before package repair.
check_network_reachable warn

if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qx yes; then
    log_ok "NTP synchronized"
else
    log_warn "NTP not synchronized - pacman/paru may reject signatures; enable systemd-timesyncd"
fi

# 6. Repair official bootstrap packages and rejected power-policy packages.
install_missing_base_packages
remove_rejected_power_policy

# 7. NetworkManager is the supported network stack for this desktop.
ensure_networkmanager
check_network_reachable fatal

# 8. Microcode actually loaded (warn-only; package presence was checked above).
if grep -qE 'microcode' /proc/cpuinfo 2>/dev/null && \
   journalctl -k --no-pager 2>/dev/null | grep -qiE 'microcode.*updated' ; then
    log_ok "AMD microcode loaded by the kernel"
else
    log_warn "could not confirm microcode update from kernel log; verify the bootloader entry loads /amd-ucode.img before initramfs"
fi

# 9. User groups.
require_groups video input audio

# 10. AMD render node.
if [[ ! -e /dev/dri/renderD128 ]]; then
    log_fatal "/dev/dri/renderD128 not found - AMD GPU drivers missing or DRM disabled"
    exit 1
fi
log_ok "AMD render node /dev/dri/renderD128 present"

# 11. AUR helper.
# Validate paru actually runs, not just that the binary is on PATH. A
# broken paru-bin (libalpm ABI mismatch) shows up as "command exists but
# errors on every run".
if ! command -v paru &>/dev/null || ! paru --version &>/dev/null; then
    log_info "paru missing or not working - bootstrapping from AUR"
    bootstrap_paru || { log_fatal "paru bootstrap failed"; exit 1; }
fi
if ! paru --version &>/dev/null; then
    log_fatal "paru installed but does not run; check libalpm ABI compatibility"
    exit 1
fi
log_ok "paru available: $(command -v paru) ($(paru --version 2>&1 | head -1))"

# 12. State + backup directories.
run mkdir -p "$STATE_DIR" "$BACKUP_DIR"
log_ok "state dir:  $STATE_DIR"
log_ok "backup dir: $BACKUP_DIR"

log_ok "Stage 00 complete - ready to run stage 01 (shell)"
