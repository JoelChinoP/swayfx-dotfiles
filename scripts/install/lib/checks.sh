#!/usr/bin/env bash
# Automated post-install checks.
#
# This script intentionally separates "installed/configured" checks from
# live SwayFX-session checks. Stage 10 may run before the user logs out
# and starts SwayFX, so live-session checks are WARN by default. Run with
# CHECK_LIVE=1 after logging into SwayFX to make live checks fatal.
#
# Verified against: .claude/CONTEXT.md acceptance checklist
# Reviewed: 2026-05-12

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"

CHECK_LIVE="${CHECK_LIVE:-0}"
FAILS=0
WARNS=0

pass() { log_ok "check: $*"; }
fail() { log_error "check: $*"; (( ++FAILS )); }
warn_check() { log_warn "check: $*"; (( ++WARNS )); }

check_cmd() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

check_live_cmd() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    elif (( CHECK_LIVE )); then
        fail "$label"
    else
        warn_check "$label (requires active SwayFX session)"
    fi
}

log_info "Running post-install checks"

if [[ -f /etc/arch-release ]]; then
    pass "Arch system detected"
else
    fail "Arch system detected"
fi

check_cmd "core packages installed" pacman -Q amd-ucode sof-firmware sudo zsh starship stow
check_cmd "installer bootstrap packages installed" pacman -Q base-devel git lm_sensors jq curl wget openssh unzip zip p7zip
check_cmd "rejected power policy packages absent" bash -c '
for pkg in power-profiles-daemon tlp auto-cpufreq ryzenadj; do
    pacman -Q "$pkg" >/dev/null 2>&1 && exit 1
done
exit 0
'
check_cmd "NetworkManager active" systemctl is-active NetworkManager.service
check_cmd "systemd-timesyncd active" systemctl is-active systemd-timesyncd.service
check_cmd "zsh is login shell" bash -c 'getent passwd "$USER" | grep -q "/zsh$"'
check_cmd "dark color scheme set" bash -c '[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" = "'\''prefer-dark'\''" ]'
check_cmd "FiraCode Nerd Font installed" bash -c "fc-match -f '%{family}\n' 'FiraCode Nerd Font Mono' | grep -qi 'FiraCode.*Nerd'"
check_cmd "JetBrainsMono Nerd Font installed" bash -c "fc-match -f '%{family}\n' 'JetBrainsMono Nerd Font' | grep -qi 'JetBrains.*Nerd'"
check_cmd "Inter font installed" bash -c "fc-match -f '%{family}\n' 'Inter' | grep -qi 'Inter'"
check_cmd "cpupower installed" command -v cpupower
check_cmd "CPU frequency ceiling service enabled" systemctl is-enabled swayfx-cpu-frequency-limit.service
check_cmd "CPU frequency ceiling active" bash -c '
shopt -s nullglob
files=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq)
(( ${#files[@]} > 0 )) || exit 1

expected=2000000
for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/type" && -r "$supply/online" ]] || continue
    type="$(< "$supply/type")"
    online="$(< "$supply/online")"
    if [[ "$type" != "Battery" && "$online" = "1" ]]; then
        expected=3000000
        break
    fi
done

for file in "${files[@]}"; do
    read -r value < "$file"
    (( value <= expected )) || exit 1
done
'
check_cmd "zram0 present" bash -c 'zramctl 2>/dev/null | grep -q zram0'
check_cmd "zram swappiness tuned" bash -c '[ "$(sysctl -n vm.swappiness 2>/dev/null)" = "180" ]'
check_cmd "zram page-cluster tuned" bash -c '[ "$(sysctl -n vm.page-cluster 2>/dev/null)" = "0" ]'
check_cmd "starship config linked" bash -c 'test -e "$HOME/.config/starship.toml"'
check_cmd "sway config linked" bash -c 'test -e "$HOME/.config/sway/config"'
check_cmd "waybar top config linked" bash -c 'test -e "$HOME/.config/waybar/top.jsonc"'
check_cmd "waybar bottom config linked" bash -c 'test -e "$HOME/.config/waybar/bottom.jsonc"'
for helper in \
    swayfx-cpu-cap \
    swayfx-powermenu \
    swayfx-screenshot \
    swayfx-cliphist-menu \
    swayfx-waybar-notifications
do
    check_cmd "helper installed: $helper" bash -c 'test -x "$HOME/.local/bin/$1"' _ "$helper"
done

check_live_cmd "running compositor is SwayFX" bash -c 'swaymsg -t get_version 2>/dev/null | grep -qi swayfx'
check_live_cmd "two waybar instances running" bash -c '[ "$(pgrep -cx waybar 2>/dev/null || true)" -eq 2 ]'
check_live_cmd "PipeWire responds" wpctl status
check_live_cmd "VAAPI reports decode entrypoint" bash -c 'vainfo --display drm --device /dev/dri/renderD128 2>/dev/null | grep -q VAEntrypoint'
check_live_cmd "lm_sensors reports CPU/GPU temp" bash -c "sensors 2>/dev/null | grep -qE 'k10temp|coretemp|amdgpu'"
check_live_cmd "notification daemon works" bash -c 'notify-send "swayfx-dotfiles" "ok"'

if (( FAILS > 0 )); then
    log_fatal "checks failed: $FAILS failure(s), $WARNS warning(s)"
    exit 1
fi

log_ok "checks complete: 0 failure(s), $WARNS warning(s)"
if (( WARNS > 0 && ! CHECK_LIVE )); then
    log_warn "run CHECK_LIVE=1 $ROOT/scripts/install/lib/checks.sh inside SwayFX for live-session checks"
fi
