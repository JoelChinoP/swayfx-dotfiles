#!/usr/bin/env bash
# Stage 02 - Base Wayland stack.
#
# Installs vanilla Sway, AMD userspace drivers, PipeWire audio,
# XWayland/Qt Wayland support, polkit, sensors, and CPU frequency
# ceilings for AC/battery.
# SwayFX is deliberately not installed here; stage 03 performs that swap.
#
# Verified against: .claude/PLAN.md §2 stage 02
# Reviewed: 2026-05-12

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
    lm_sensors cpupower
)

if command -v pacman >/dev/null 2>&1 && pkg_installed swayfx; then
    log_info "swayfx is already installed; skipping vanilla sway package on resume"
else
    BASE_PKGS=(sway "${BASE_PKGS[@]}")
fi

pacman_install "${BASE_PKGS[@]}"

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

install_system_template \
    "$ROOT/system/usr/local/lib/swayfx-dotfiles/cpu-frequency-limit" \
    /usr/local/lib/swayfx-dotfiles/cpu-frequency-limit \
    0755
install_system_template \
    "$ROOT/system/systemd/system/swayfx-cpu-frequency-limit.service" \
    /etc/systemd/system/swayfx-cpu-frequency-limit.service \
    0644
install_system_template \
    "$ROOT/system/udev/rules.d/90-swayfx-cpu-frequency-limit.rules" \
    /etc/udev/rules.d/90-swayfx-cpu-frequency-limit.rules \
    0644

log_info "enabling PipeWire user services"
run systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service

log_info "enabling CPU frequency ceiling service"
run sudo systemctl daemon-reload
run sudo udevadm control --reload
run sudo systemctl enable --now swayfx-cpu-frequency-limit.service

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

if command -v cpupower >/dev/null 2>&1; then
    log_ok "cpupower is installed"
else
    log_error "cpupower is not on PATH"
    (( ++errs ))
fi

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

if systemctl is-enabled swayfx-cpu-frequency-limit.service >/dev/null 2>&1; then
    log_ok "CPU frequency ceiling service is enabled"
else
    log_error "CPU frequency ceiling service is not enabled"
    (( ++errs ))
fi

if compgen -G '/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq' >/dev/null; then
    if sudo systemctl start swayfx-cpu-frequency-limit.service >/dev/null 2>&1; then
        log_ok "CPU frequency ceiling service runs"
    else
        log_error "CPU frequency ceiling service failed"
        (( ++errs ))
    fi
elif (( IS_VM )); then
    log_warn "no cpufreq sysfs in VM; skipping CPU frequency ceiling validation"
else
    log_error "no cpufreq scaling_max_freq files found"
    (( ++errs ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 02 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 02 complete - vanilla Sway base is ready"
