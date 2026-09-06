#!/usr/bin/env bash
# Stage 06 - Session utilities.
#
# Installs clipboard, screenshots, brightness, network, bluetooth,
# Tailscale, idle, notifications helper, JSON helper, and ASUS power tooling.
#
# Verified against: .claude/PLAN.md stage 06, https://wiki.archlinux.org/title/Tailscale,
#                   https://gitlab.com/asus-linux/asusctl, busctl(1)
# Reviewed: 2026-08-24

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 06 - utilities"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

UTIL_PKGS=(
    wl-clipboard cliphist
    grim slurp satty
    brightnessctl gammastep
    wdisplays pavucontrol playerctl
    networkmanager network-manager-applet
    bluez bluez-utils blueman
    swayidle libnotify
    jq ufw tailscale
)
pacman_install "${UTIL_PKGS[@]}"

log_info "enabling NetworkManager, bluetooth, and tailscaled"
run sudo systemctl enable --now NetworkManager.service bluetooth.service tailscaled.service

TAILSCALE_SUDOERS_SRC="$ROOT/system/sudoers.d/90-tailscale-operator"
TAILSCALE_SUDOERS_DEST=/etc/sudoers.d/90-tailscale-operator

if ! visudo -cf "$TAILSCALE_SUDOERS_SRC" >/dev/null; then
    log_fatal "invalid Tailscale sudoers template"
    exit 1
fi

if (( DRY_RUN )); then
    log_info "would install $TAILSCALE_SUDOERS_SRC -> $TAILSCALE_SUDOERS_DEST"
else
    if sudo test -e "$TAILSCALE_SUDOERS_DEST" \
        && ! sudo cmp -s "$TAILSCALE_SUDOERS_SRC" "$TAILSCALE_SUDOERS_DEST"; then
        ts="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"
        backup_path="$BACKUP_DIR/$ts$TAILSCALE_SUDOERS_DEST"
        mkdir -p "$(dirname "$backup_path")"
        sudo cp -a "$TAILSCALE_SUDOERS_DEST" "$backup_path"
        log_warn "backed up $TAILSCALE_SUDOERS_DEST to $backup_path"
    fi
    sudo install -Dm 0440 "$TAILSCALE_SUDOERS_SRC" "$TAILSCALE_SUDOERS_DEST"
    sudo visudo -cf "$TAILSCALE_SUDOERS_DEST" >/dev/null
    log_ok "installed $TAILSCALE_SUDOERS_DEST"
fi

paru_install nmgui-bin asusctl

log_info "configuring ASUS power profiles and battery protection"
run sudo systemctl start asusd.service

ASUSD_SERVICE=xyz.ljones.Asusd
ASUSD_OBJECT=/xyz/ljones
ASUSD_INTERFACE=xyz.ljones.Platform
run busctl set-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" PlatformProfileLinkedEpp b true
run busctl set-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ChangePlatformProfileOnAc b true
run busctl set-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ChangePlatformProfileOnBattery b true
# asusd 6.x EPP enum: BalancePower=3, Power=4.
run busctl set-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ProfileBalancedEpp u 3
run busctl set-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ProfileQuietEpp u 4
run asusctl profile set -a Balanced
run asusctl profile set -b Quiet
run asusctl battery limit 92

active_profile=Quiet
for supply in /sys/class/power_supply/*; do
    [[ -r "$supply/type" && -r "$supply/online" ]] || continue
    if [[ "$(< "$supply/type")" != "Battery" && "$(< "$supply/online")" == "1" ]]; then
        active_profile=Balanced
        break
    fi
done
run asusctl profile set "$active_profile"

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 06 dry-run complete"
    exit 0
fi

errs=0

for cmd in wl-copy cliphist grim slurp brightnessctl gammastep wdisplays pavucontrol playerctl nmcli bluetoothctl notify-send jq ufw tailscale asusctl; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log_ok "command present: $cmd"
    else
        log_error "command missing: $cmd"
        (( ++errs ))
    fi
done

if systemctl is-active asusd.service >/dev/null 2>&1; then
    log_ok "asusd.service active"
else
    log_error "asusd.service is not active"
    (( ++errs ))
fi

asus_profiles="$(asusctl profile get 2>/dev/null || true)"
if grep -qx "Active profile: $active_profile" <<<"$asus_profiles" \
    && grep -qx 'AC profile Balanced' <<<"$asus_profiles" \
    && grep -qx 'Battery profile Quiet' <<<"$asus_profiles"; then
    log_ok "ASUS active/AC/battery profiles configured"
else
    log_error "ASUS active/AC/battery profiles are incorrect"
    (( ++errs ))
fi

if [[ "$(busctl get-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" PlatformProfileLinkedEpp 2>/dev/null)" == "b true" \
    && "$(busctl get-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ChangePlatformProfileOnAc 2>/dev/null)" == "b true" \
    && "$(busctl get-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ChangePlatformProfileOnBattery 2>/dev/null)" == "b true" \
    && "$(busctl get-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ProfileBalancedEpp 2>/dev/null)" == "u 3" \
    && "$(busctl get-property "$ASUSD_SERVICE" "$ASUSD_OBJECT" "$ASUSD_INTERFACE" ProfileQuietEpp 2>/dev/null)" == "u 4" ]]; then
    log_ok "ASUS automatic profile/EPP mapping configured"
else
    log_error "ASUS automatic profile/EPP mapping is incorrect"
    (( ++errs ))
fi

expected_epp=power
if [[ "$active_profile" == "Balanced" ]]; then
    expected_epp=balance_power
fi
epp_found=0
epp_valid=1
for file in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference; do
    [[ -r "$file" ]] || continue
    epp_found=1
    [[ "$(< "$file")" == "$expected_epp" ]] || epp_valid=0
done
if (( epp_found && epp_valid )); then
    log_ok "ASUS EPP active: $expected_epp"
else
    log_error "ASUS EPP is not $expected_epp on every CPU"
    (( ++errs ))
fi

if asusctl battery info 2>/dev/null | grep -qx 'Current battery charge limit: 92%'; then
    log_ok "battery charge limit set to 92%"
else
    log_error "battery charge limit is not 92%"
    (( ++errs ))
fi

if nmcli -t -f STATE general 2>/dev/null | grep -qE 'connected|disconnected|connecting'; then
    log_ok "NetworkManager responds to nmcli"
else
    log_error "nmcli did not report NetworkManager state"
    (( ++errs ))
fi

if brightnessctl get >/dev/null 2>&1; then
    log_ok "brightnessctl can read brightness"
else
    log_warn "brightnessctl could not read brightness; this may be VM or permissions"
fi

if systemctl is-enabled bluetooth.service >/dev/null 2>&1; then
    log_ok "bluetooth.service enabled"
else
    log_warn "bluetooth.service not enabled; skip if hardware has no bluetooth"
fi

if systemctl is-enabled tailscaled.service >/dev/null 2>&1 \
    && systemctl is-active tailscaled.service >/dev/null 2>&1; then
    log_ok "tailscaled.service enabled and active"
else
    log_error "tailscaled.service is not enabled and active"
    (( ++errs ))
fi

if sudo visudo -cf "$TAILSCALE_SUDOERS_DEST" >/dev/null 2>&1; then
    log_ok "Tailscale first-login policy is valid"
else
    log_error "Tailscale first-login policy is invalid"
    (( ++errs ))
fi

status="$(/usr/bin/tailscale status --json 2>/dev/null || true)"
bootstrap="$(jq -r '
    .BackendState == "NoState" or
    (.BackendState == "NeedsLogin" and .CurrentTailnet == null and (.Self.UserID // 0) == 0)
' <<<"$status" 2>/dev/null || true)"
prefs_valid=false
operator=
if prefs="$(/usr/bin/tailscale debug prefs 2>/dev/null)" \
    && jq -e '(.OperatorUser? == null) or ((.OperatorUser | type) == "string")' \
        <<<"$prefs" >/dev/null; then
    prefs_valid=true
    operator="$(jq -r '.OperatorUser // empty' <<<"$prefs")"
fi
if jq -e '(.BackendState | type) == "string"' <<<"$status" >/dev/null \
    && { [[ "$bootstrap" == true ]] \
        || [[ "$prefs_valid" == true && ( -z "$operator" || "$operator" == "$USER" ) ]]; }; then
    log_ok "Tailscale login pending or operator configured"
else
    log_error "Tailscale preferences are invalid or not operated by $USER"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 06 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 06 complete - utilities are installed"
