#!/usr/bin/env bash
# Stage 02 - Base Wayland stack.
#
# Installs vanilla Sway, AMD userspace drivers, PipeWire audio,
# XWayland/Qt Wayland support, polkit, sensors, and power profiles.
# SwayFX is deliberately not installed here; stage 03 performs that swap.
#
# Verified against: .claude/PLAN.md §2 stage 02
# Reviewed: 2026-05-11

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 02 - base Wayland stack"

if (( DRY_RUN )); then
    log_warn "skipping sudo verification (dry-run)"
else
    log_info "verifying sudo (may prompt for password)"
    sudo true || { log_fatal "sudo failed"; exit 1; }
fi

# A VM used for installer tests may expose virtio/QXL instead of AMD.
# Keep AMD-specific graphics/sensor validation strict on real hardware,
# but warn instead of failing under virtualization.
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet; then
    IS_VM=1
else
    IS_VM=0
fi

BASE_PKGS=(
    swaybg foot ghostty
    mesa vulkan-radeon libva-utils
    pipewire wireplumber pipewire-pulse pipewire-jack
    sof-firmware alsa-ucm-conf
    xorg-xwayland qt5-wayland qt6-wayland
    xdg-utils xdg-user-dirs polkit polkit-gnome
    lm_sensors power-profiles-daemon
)

if command -v pacman >/dev/null 2>&1 && pkg_installed swayfx; then
    log_info "swayfx is already installed; skipping vanilla sway package on resume"
else
    BASE_PKGS=(sway "${BASE_PKGS[@]}")
fi

pacman_install "${BASE_PKGS[@]}"

log_info "enabling PipeWire user services"
run systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

log_info "enabling power-profiles-daemon"
run sudo systemctl enable --now power-profiles-daemon.service

log_info "detecting sensors"
run sudo sensors-detect --auto

if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 02 dry-run complete"
    exit 0
fi

errs=0

if command -v sway >/dev/null 2>&1; then
    log_ok "sway is installed: $(command -v sway)"
else
    log_error "sway is not on PATH"
    (( ++errs ))
fi

for terminal in foot ghostty; do
    if command -v "$terminal" >/dev/null 2>&1; then
        log_ok "$terminal is installed"
    else
        log_error "$terminal is not on PATH"
        (( ++errs ))
    fi
done

if [[ -e /dev/dri/renderD128 ]]; then
    log_ok "render node present: /dev/dri/renderD128"
else
    log_error "missing /dev/dri/renderD128"
    (( ++errs ))
fi

if [[ -r /sys/class/drm/renderD128/device/vendor ]]; then
    gpu_vendor="$(< /sys/class/drm/renderD128/device/vendor)"
else
    gpu_vendor=""
fi

if [[ "$gpu_vendor" == "0x1002" ]]; then
    if vainfo --display drm --device /dev/dri/renderD128 2>&1 | grep -q VAEntrypoint; then
        log_ok "VAAPI works on AMD render node"
    else
        log_error "VAAPI validation failed on AMD render node"
        (( ++errs ))
    fi
elif (( IS_VM )); then
    log_warn "non-AMD render node in VM (${gpu_vendor:-unknown}); skipping AMD VAAPI validation"
else
    log_error "render node is not AMD (${gpu_vendor:-unknown})"
    (( ++errs ))
fi

if wpctl status >/dev/null 2>&1; then
    log_ok "PipeWire/WirePlumber responds to wpctl"
else
    log_error "wpctl status failed"
    (( ++errs ))
fi

if sensors 2>/dev/null | grep -qE 'k10temp|coretemp|amdgpu'; then
    log_ok "lm_sensors reports CPU/GPU temperature data"
elif (( IS_VM )); then
    log_warn "no CPU/GPU sensor chip found in VM; skipping sensor validation"
else
    log_error "lm_sensors did not report k10temp/coretemp/amdgpu"
    (( ++errs ))
fi

if powerprofilesctl list 2>/dev/null | grep -q balanced; then
    log_ok "power-profiles-daemon reports balanced profile"
elif (( IS_VM )); then
    log_warn "powerprofilesctl did not report balanced in VM; hardware support may be absent"
else
    log_error "powerprofilesctl list did not report balanced"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 02 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 02 complete - vanilla Sway base is ready"
