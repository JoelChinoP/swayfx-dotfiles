#!/usr/bin/env bash
# Automated post-install checks.
#
# This script intentionally separates "installed/configured" checks from
# live SwayFX-session checks. Stage 10 may run before the user logs out
# and starts SwayFX, so live-session checks are WARN by default. Run with
# CHECK_LIVE=1 after logging into SwayFX to make live checks fatal.
#
# Verified against: .claude/CONTEXT.md acceptance checklist
# Reviewed: 2026-07-25

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
check_cmd "installer bootstrap packages installed" pacman -Q git lm_sensors jq less curl wget openssh unzip zip p7zip
check_cmd "base-devel toolchain installed" bash -c '
for cmd in makepkg make gcc fakeroot pkgconf; do
    command -v "$cmd" >/dev/null 2>&1 || exit 1
done
'
check_cmd "rejected power policy packages absent" bash -c '
for pkg in power-profiles-daemon tlp auto-cpufreq ryzenadj; do
    pacman -Q "$pkg" >/dev/null 2>&1 && exit 1
done
exit 0
'
check_cmd "NetworkManager active" systemctl is-active NetworkManager.service
check_cmd "systemd-timesyncd active" systemctl is-active systemd-timesyncd.service
check_cmd "Tailscale installed" pacman -Q tailscale
check_cmd "Tailscale daemon enabled" systemctl is-enabled tailscaled.service
check_cmd "Tailscale daemon active" systemctl is-active tailscaled.service
check_cmd "Tailscale wrapper installed" test -x "$HOME/.local/bin/tailscale"
check_cmd "Tailscale wrapper syntax" bash -n "$HOME/.local/bin/tailscale"
check_cmd "Tailscale login pending or operator configured" bash -c '
status="$(/usr/bin/tailscale status --json 2>/dev/null || true)"
jq -e "(.BackendState | type) == \"string\"" <<<"$status" >/dev/null || exit 1
bootstrap="$(jq -r '\''
    .BackendState == "NoState" or
    (.BackendState == "NeedsLogin" and .CurrentTailnet == null and (.Self.UserID // 0) == 0)
'\'' <<<"$status")"
[[ "$bootstrap" == true ]] && exit 0
prefs="$(/usr/bin/tailscale debug prefs 2>/dev/null)" || exit 1
jq -e '\''(.OperatorUser? == null) or ((.OperatorUser | type) == "string")'\'' <<<"$prefs" >/dev/null || exit 1
operator="$(jq -r ".OperatorUser // empty" <<<"$prefs")"
[[ -z "$operator" || "$operator" == "$USER" ]]
'
check_cmd "Tailscale remote lifecycle state" bash -c '
status="$(/usr/bin/tailscale status --json 2>/dev/null || true)"
jq -e "(.BackendState | type) == \"string\"" <<<"$status" >/dev/null || exit 1
bootstrap="$(jq -r '\''
    .BackendState == "NoState" or
    (.BackendState == "NeedsLogin" and .CurrentTailnet == null and (.Self.UserID // 0) == 0)
'\'' <<<"$status")"
[[ "$bootstrap" == true ]] && exit 0
prefs="$(/usr/bin/tailscale debug prefs 2>/dev/null)" || exit 1
jq -e '\''(.OperatorUser? == null) or ((.OperatorUser | type) == "string")'\'' <<<"$prefs" >/dev/null || exit 1
operator="$(jq -r ".OperatorUser // empty" <<<"$prefs")"
[[ -z "$operator" ]] && exit 0
[[ "$operator" == "$USER" ]] || exit 1
want_running="$(jq -r ".WantRunning" <<<"$prefs")"
run_ssh="$(jq -r ".RunSSH" <<<"$prefs")"
serve="$(/usr/bin/tailscale serve status --json 2>/dev/null)" || exit 1
if [[ "$want_running" == true ]]; then
    [[ "$run_ssh" == true ]] || exit 1
    config_dir="$HOME/.config/opencode-dotfiles"
    [[ -r "$config_dir/defaults.env" ]] && source "$config_dir/defaults.env"
    [[ -r "$config_dir/dotfiles.env" ]] && source "$config_dir/dotfiles.env"
    target="http://127.0.0.1:${OPENCODE_SERVE_PORT:-4096}"
    auth_status="$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$target/global/health" || true)"
    [[ "$auth_status" == 401 || "$auth_status" =~ ^2[0-9][0-9]$ ]] || exit 1
    jq -e --arg target "$target" '\''
        keys == ["TCP", "Web"] and
        (.TCP | keys == ["443"]) and
        .TCP["443"].HTTPS == true and
        (.Web | length) == 1 and
        all(.Web[]; (.Handlers | keys) == ["/"] and .Handlers["/"].Proxy == $target)
    '\'' <<<"$serve" >/dev/null
else
    [[ "$run_ssh" == false ]] && jq -e ". == {} or . == null" <<<"$serve" >/dev/null
fi
'
check_cmd "zsh is login shell" bash -c 'getent passwd "$USER" | grep -q "/zsh$"'
check_cmd "dark color scheme set" bash -c '[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)" = "'\''prefer-dark'\''" ]'
check_cmd "FiraCode Nerd Font installed" bash -c "fc-match -f '%{family}\n' 'FiraCode Nerd Font Mono' | grep -qi 'FiraCode.*Nerd'"
check_cmd "JetBrainsMono Nerd Font installed" bash -c "fc-match -f '%{family}\n' 'JetBrainsMono Nerd Font' | grep -qi 'JetBrains.*Nerd'"
check_cmd "Inter font installed" bash -c "fc-match -f '%{family}\n' 'Inter' | grep -qi 'Inter'"
check_cmd "Python i3ipc module installed" /usr/bin/python -c 'import i3ipc'
check_cmd "Brave Origin installed" pacman -Q brave-origin-bin
check_cmd "Mermaid CLI installed" command -v mmdc
check_cmd "standard Brave package absent" bash -c '
for pkg in brave-bin brave-beta-bin brave-nightly-bin brave-browser; do
    pacman -Q "$pkg" >/dev/null 2>&1 && exit 1
done
exit 0
'
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
check_cmd "logind ignores physical power key" bash -c 'grep -q "^HandlePowerKey=ignore$" /etc/systemd/logind.conf.d/10-swayfx-power-key.conf'
check_cmd "starship config linked" bash -c 'test -e "$HOME/.config/starship.toml"'
check_cmd "sway config linked" bash -c 'test -e "$HOME/.config/sway/config"'
check_cmd "waybar top config linked" bash -c 'test -e "$HOME/.config/waybar/top.jsonc"'
check_cmd "waybar bottom config linked" bash -c 'test -e "$HOME/.config/waybar/bottom.jsonc"'
check_cmd "wlogout layout linked" bash -c 'test -e "$HOME/.config/wlogout/layout"'
check_cmd "wlogout layout object stream" bash -c '
layout="$HOME/.config/wlogout/layout"
grep -q "\"label\"" "$layout" || exit 1
! grep -q "^[[:space:]]*\\[" "$layout"
'
for helper in \
    swayfx-cpu-cap \
    swayfx-powermenu \
    swayfx-maximize \
    swayfx-daemon-watch \
    swayfx-placement-daemon \
    swayfx-screenshot \
    swayfx-cliphist-menu \
    swayfx-waybar-notifications \
    swayfx-waybar-bottom-toggle \
    swayfx-waycal-toggle \
    swayfx-browser \
    swayfx-refresh-rate
do
    check_cmd "helper installed: $helper" bash -c 'test -x "$HOME/.local/bin/$1"' _ "$helper"
done

check_live_cmd "running compositor is SwayFX" bash -c '
swaymsg -t get_version >/dev/null 2>&1 || exit 1
sway --version 2>/dev/null | grep -qi swayfx || pacman -Q swayfx >/dev/null 2>&1
'
check_live_cmd "two waybar instances running" bash -c '[ "$(pgrep -cx waybar 2>/dev/null || true)" -eq 2 ]'
check_live_cmd "display refresh matches power source" bash -c '
target=48000
for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/type" && -r "$supply/online" ]] || continue
    type="$(< "$supply/type")"
    online="$(< "$supply/online")"
    if [[ "$type" != "Battery" && "$online" = "1" ]]; then
        target=60000
        break
    fi
done

swaymsg -t get_outputs 2>/dev/null | jq -e --argjson target "$target" --argjson tolerance 1000 "
def abs: if . < 0 then -. else . end;
[
  .[]
  | select(.active == true and .current_mode != null)
  | . as \$output
  | select(any(.modes[]; .width == \$output.current_mode.width and .height == \$output.current_mode.height and (((.refresh - \$target) | abs) <= \$tolerance)))
  | select(((.current_mode.refresh - \$target) | abs) <= \$tolerance)
]
| length > 0
" >/dev/null
'
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
