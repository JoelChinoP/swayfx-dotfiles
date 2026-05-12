#!/usr/bin/env bash
# Stage 00 — Pre-flight.
#
# Validates that Arch minimal is correctly installed (CONTEXT §2), adds
# the user to required groups if needed, bootstraps the AUR helper if
# missing, and prepares state/backup directories.
#
# IMPORTANT: this stage installs nothing other than `paru` (only when
# missing). The Arch minimal pacstrap (see .claude/STACK.md §1) must
# already be complete before running this.
#
# Verified against: .claude/PLAN.md §2 stage 00
# Reviewed: 2026-05-10

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 00 — preflight"

# ── 1. Distro identity ────────────────────────────────────────────────
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

# ── 2. Architecture ───────────────────────────────────────────────────
arch="$(uname -m)"
[[ "$arch" == "x86_64" ]] || { log_fatal "unsupported architecture: $arch"; exit 1; }
log_ok "architecture: x86_64"

# ── 3. UEFI (warn-only) ───────────────────────────────────────────────
if [[ -d /sys/firmware/efi/efivars ]]; then
    log_ok "UEFI firmware detected"
else
    log_warn "system is not UEFI — bootloader assumptions in PLAN may not hold"
fi

# ── 4. Required base packages from the pacstrap ───────────────────────
REQUIRED_PKGS=(
    linux-firmware sof-firmware amd-ucode
    networkmanager sudo git base-devel
    zsh starship stow
    lm_sensors jq
    unzip zip p7zip
)
if ! require_pkgs "${REQUIRED_PKGS[@]}"; then
    log_fatal "complete the Arch minimal pacstrap (.claude/STACK.md §1) and re-run"
    exit 1
fi
log_ok "all required base packages present"

# ── 5. Microcode actually loaded ──────────────────────────────────────
if grep -qE 'microcode' /proc/cpuinfo 2>/dev/null && \
   journalctl -k --no-pager 2>/dev/null | grep -qiE 'microcode.*updated' ; then
    log_ok "AMD microcode loaded by the kernel"
else
    log_warn "could not confirm microcode update from kernel log; verify the bootloader entry loads /amd-ucode.img before initramfs"
fi

# ── 6. NetworkManager enabled and active ──────────────────────────────
if ! systemctl is-enabled NetworkManager.service &>/dev/null; then
    log_fatal "NetworkManager.service is not enabled"
    exit 1
fi
if ! systemctl is-active NetworkManager.service &>/dev/null; then
    log_fatal "NetworkManager.service is not active"
    exit 1
fi
log_ok "NetworkManager enabled and active"

# ── 7. Real network connectivity ──────────────────────────────────────
if ping -c 1 -W 3 archlinux.org &>/dev/null; then
    log_ok "internet reachable (ping archlinux.org)"
elif command -v nm-online &>/dev/null && nm-online -t 5 &>/dev/null; then
    log_warn "ping blocked but nm-online reports a connection — continuing"
else
    log_fatal "no internet connection"
    exit 1
fi

# ── 8. Time sync (warn-only — but pacman/paru may break) ──────────────
if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qx yes; then
    log_ok "NTP synchronized"
else
    log_warn "NTP not synchronized — pacman/paru may reject signatures; enable systemd-timesyncd"
fi

# ── 9. Sudo works ─────────────────────────────────────────────────────
# We use `sudo true` (a real no-op) instead of `sudo -v` because the
# validate flag (-v) fails when the user has multiple sudoers rules and
# any of them requires a password — even if a NOPASSWD rule also
# matches. Running a real command exercises the actual auth path and
# also primes the credential cache for subsequent sudo calls.
log_info "verifying sudo (may prompt for password)"
if ! sudo true; then
    log_fatal "sudo failed (user may not be in wheel, or password rejected)"
    exit 1
fi
log_ok "sudo verified"

# ── 10. User groups ───────────────────────────────────────────────────
require_groups video input audio

# ── 11. AMD render node ───────────────────────────────────────────────
if [[ ! -e /dev/dri/renderD128 ]]; then
    log_fatal "/dev/dri/renderD128 not found — AMD GPU drivers missing or DRM disabled"
    exit 1
fi
log_ok "AMD render node /dev/dri/renderD128 present"

# ── 12. AUR helper ────────────────────────────────────────────────────
# Validate paru actually runs (`paru --version`), not just that the
# binary is on PATH. A broken paru-bin (libalpm ABI mismatch) shows up
# as "command exists but errors on every run".
if ! command -v paru &>/dev/null || ! paru --version &>/dev/null; then
    log_info "paru missing or not working — bootstrapping from AUR"
    bootstrap_paru || { log_fatal "paru bootstrap failed"; exit 1; }
fi
if ! paru --version &>/dev/null; then
    log_fatal "paru installed but does not run; check libalpm ABI compatibility"
    exit 1
fi
log_ok "paru available: $(command -v paru) ($(paru --version 2>&1 | head -1))"

# ── 13. State + backup directories ────────────────────────────────────
run mkdir -p "$STATE_DIR" "$BACKUP_DIR"
log_ok "state dir:  $STATE_DIR"
log_ok "backup dir: $BACKUP_DIR"

# ── Summary ───────────────────────────────────────────────────────────
log_ok "Stage 00 complete — ready to run stage 01 (shell)"
