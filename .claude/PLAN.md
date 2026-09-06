# PLAN.md — Staged Installation Plan

> Read [CONTEXT.md](CONTEXT.md) first. If this plan contradicts CONTEXT,
> CONTEXT wins. Package decisions live in [STACK.md](STACK.md). Reference
> repo notes and upstream SwayFX syntax live in [REFERENCES.md](REFERENCES.md).
>
> Last reviewed: 2026-08-26.

Hardware: ASUS · Ryzen 7 7730U · Vega 8 · 16 GB RAM · Arch Linux.
Goal: SwayFX desktop usable as a conventional desktop, dark-only,
pure-black palette, RAM idle < 600 MB (target ~560 MB; see
[STACK §6](STACK.md)).

---

## 0. Plan philosophy

- **One stage = one script** in `scripts/install/stages/NN-*.sh`.
- Each stage validates and exits non-zero if anything fails.
- The master `scripts/install/run.sh` runs stages in order and stops on
  the first failure. Resumable with `--from NN`.
- Each stage is **idempotent** (`--needed`, `stow -R`, presence checks).
- **Dotfiles are NOT applied stage-by-stage**: stages 02–09 install
  packages and write system files; the user dotfiles are applied all at
  once in `10-final.sh` via `stow -R`. This avoids half-applied configs
  breaking the next stage.
- **Exception**: stage `01-shell` does `stow -R zsh starship` because the
  rest of the chain depends on a working interactive shell.
- Stage `99-greetd.sh` (graphical login) is **optional** and not part of
  `--all`. Run only after the rest is stable.

---

## 1. Master script: `scripts/install/run.sh`

Synopsis:

```
./scripts/install/run.sh [--all] [--from NN] [--only NN] [--list]
                         [--dry-run] [--yes]
```

- `--list`: print stages and exit.
- `--from 04`: start at stage 04.
- `--only 03`: run stage 03 only.
- `--all`: run every stage in order.
- `--dry-run`: propagate `DRY_RUN=1`; print actions, do not execute.
- `--yes`: skip the upfront confirmation prompt.

Pseudocode:

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/scripts/install/lib/common.sh"

STAGES=( $(ls "$ROOT/scripts/install/stages" | sort) )
[[ "${1:-}" == "--list" ]] && { printf '%s\n' "${STAGES[@]}"; exit 0; }

FROM="${FROM:-00}"; ONLY=""; DRY_RUN=0; YES=0
parse_flags "$@"

for s in "${STAGES[@]}"; do
  num="${s%%-*}"
  [[ -n "$ONLY" && "$num" != "$ONLY" ]] && continue
  [[ "$num" < "$FROM" ]] && continue
  log_info "▶ Stage $s"
  if DRY_RUN=$DRY_RUN bash "$ROOT/scripts/install/stages/$s"; then
    log_ok "✓ Stage $s"
    mkdir -p ~/.local/state/swayfx-dotfiles/stages
    touch ~/.local/state/swayfx-dotfiles/stages/$num.done
  else
    log_fatal "✗ Stage $s failed — aborting"
    exit 1
  fi
done

log_ok "All stages completed. Run the final checklist."
```

Helpers in `lib/common.sh`:

```bash
LOG_FILE="${LOG_FILE:-$HOME/swayfx-dotfiles-install.log}"
log()       { printf '[%s] [%s] %s\n' "$(date +%H:%M:%S)" "$1" "${*:2}" | tee -a "$LOG_FILE"; }
log_info()  { log INFO  "$@"; }
log_ok()    { log OK    "$@"; }
log_warn()  { log WARN  "$@"; }
log_error() { log ERROR "$@"; }
log_fatal() { log FATAL "$@"; }
run()       { (( DRY_RUN )) && { echo "DRY: $*"; return 0; }; "$@"; }
require()   { command -v "$1" >/dev/null || { log_fatal "missing: $1"; exit 1; }; }
confirm()   { (( YES )) && return 0; read -r -p "$1 [y/N] " a; [[ $a == [yY]* ]]; }
```

---

## 2. Stages

### Stage 00 — `00-preflight.sh`

**What.** Validate that Arch minimal is correctly installed (CONTEXT §2),
repair missing official bootstrap packages needed by the installer, remove
rejected power-policy daemons when confirmed, and bootstrap the AUR helper
if missing. **No graphical desktop package installs here.**

```bash
[ -f /etc/arch-release ] || { log_fatal "not Arch"; exit 1; }
sudo true
sudo pacman -S --needed --noconfirm \
  linux-firmware sof-firmware amd-ucode \
  networkmanager git base-devel \
  zsh starship stow \
  lm_sensors jq less curl wget openssh \
  unzip zip p7zip

# Remove installed conflicting power-policy layers only after confirmation/--yes.
conflicts=()
for p in power-profiles-daemon tlp auto-cpufreq ryzenadj; do
  pacman -Q "$p" &>/dev/null && conflicts+=("$p")
done
(( ${#conflicts[@]} == 0 )) || sudo pacman -Rns --noconfirm "${conflicts[@]}"

sudo systemctl enable --now NetworkManager.service
ping -c 1 archlinux.org || curl -fsI https://archlinux.org
sudo usermod -aG video,input,audio "$USER"

# Render node and EFI checks
[ -e /dev/dri/renderD128 ] || { log_fatal "no AMD render node"; exit 1; }
[ -d /sys/firmware/efi/efivars ] || log_warn "system is not UEFI — bootloader assumptions may not hold"

# AUR helper
if ! command -v paru >/dev/null; then
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmp/paru"
  ( cd "$tmp/paru" && makepkg -si --noconfirm )
fi

mkdir -p ~/.local/state/swayfx-dotfiles/stages
mkdir -p ~/.local/share/swayfx-dotfiles/backups
```

**Validation**:

```bash
command -v paru               || exit 1
command -v stow               || exit 1
pacman -Q starship jq less unzip zip p7zip || exit 1
for cmd in makepkg make gcc fakeroot pkgconf; do
  command -v "$cmd" >/dev/null || exit 1
done
for p in power-profiles-daemon tlp auto-cpufreq ryzenadj; do
  ! pacman -Q "$p" 2>/dev/null || exit 1
done
id "$USER" | grep -E 'video|input|audio'  || exit 1
[ -e /dev/dri/renderD128 ]    || exit 1
```

---

### Stage 01 — `01-shell.sh`  ← **before anything else**

**What.** Install zsh + starship + quality-of-life plugins, set zsh as
the login shell, **stow** the zsh and starship dotfiles immediately so
the rest of the chain runs in the configured shell. Includes the
`.zprofile` block that auto-starts SwayFX on TTY1.

```bash
sudo pacman -S --needed --noconfirm \
  zsh starship \
  zsh-completions zsh-syntax-highlighting zsh-autosuggestions \
  ttf-firacode-nerd ttf-jetbrains-mono-nerd inter-font

[[ "$SHELL" == */zsh ]] || sudo chsh -s "$(command -v zsh)" "$USER"

cd "$ROOT"
stow -R zsh starship
```

`zsh/.zprofile` must end with:

```bash
# Auto-start SwayFX on TTY1
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = "1" ]; then
  exec sway
fi
```

> Until stage 03 installs SwayFX, this block fails with `command not
> found: sway`. That is expected and self-resolves once stage 03 lands.
> While experimenting, the user can comment the `exec`.

**Validation**:

```bash
getent passwd "$USER" | grep -q '/zsh$'                         || exit 1
zsh -c 'starship --version'                                      || exit 1
pacman -Q zsh-syntax-highlighting zsh-autosuggestions             || exit 1
pacman -Q ttf-firacode-nerd ttf-jetbrains-mono-nerd inter-font    || exit 1
grep -q 'exec sway' "$HOME/.zprofile"                            || exit 1
```

---

### Stage 02 — `02-base.sh`

**What.** Sway vanilla (so we can verify the session before adding SwayFX
quirks), AMD drivers, audio, sensors, power management, and CPU
frequency ceilings. After this stage the user can launch a bare Sway
from TTY1 and verify VAAPI.

```bash
sudo pacman -S --needed --noconfirm \
  sway swaybg ghostty \
  mesa vulkan-radeon libva-utils \
  pipewire wireplumber pipewire-pulse pipewire-jack \
  sof-firmware alsa-ucm-conf \
  xorg-xwayland qt5-wayland qt6-wayland \
  xdg-utils xdg-user-dirs polkit polkit-gnome \
  lm_sensors cpupower

systemctl --user enable --now pipewire pipewire-pulse wireplumber
sudo install -Dm 0755 "$ROOT/system/usr/local/lib/swayfx-dotfiles/cpu-frequency-limit" \
  /usr/local/lib/swayfx-dotfiles/cpu-frequency-limit
sudo install -Dm 0644 "$ROOT/system/systemd/system/swayfx-cpu-frequency-limit.service" \
  /etc/systemd/system/swayfx-cpu-frequency-limit.service
sudo install -Dm 0644 "$ROOT/system/udev/rules.d/90-swayfx-cpu-frequency-limit.rules" \
  /etc/udev/rules.d/90-swayfx-cpu-frequency-limit.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable --now swayfx-cpu-frequency-limit.service
sudo sensors-detect --auto
```

> SwayFX is **not** installed here. We confirm vanilla Sway runs first;
> this isolates `swayfx`-specific failures from generic Sway failures.
> On resumed installs after stage 03, `02-base.sh` must skip the
> vanilla `sway` package when `swayfx` is already installed, because the
> packages intentionally conflict while still providing `/usr/bin/sway`.
> CPU limits are applied with `cpupower`, not PPD, TLP, auto-cpufreq or
> RyzenAdj. The helper detects AC from `/sys/class/power_supply` without
> hardcoding adapter or battery names. Battery uses a 2.0 GHz ceiling with
> boost disabled; AC uses 3.4 GHz with boost enabled. The helper does not
> write ASUS platform profiles or EPP; `asusd` owns those in stage 06.

**Validation**:

```bash
which sway                                                                          || exit 1
vainfo --display drm --device /dev/dri/renderD128 2>&1 | grep -q VAEntrypoint        || exit 1
wpctl status                                                                          || exit 1
sensors | grep -qE 'k10temp|coretemp|amdgpu'                                          || exit 1
command -v cpupower                                                                    || exit 1
systemctl is-enabled swayfx-cpu-frequency-limit.service                                || exit 1
```

**Manual smoke test (run by the user, not the script)**:

1. Log out.
2. Log in on TTY1.
3. `~/.zprofile` will try `exec sway`. If it does not work yet, comment
   that line and run `sway` manually to verify.
4. Inside Sway: `Mod+Return` → Ghostty. Exit. Continue with stage 03.

---

### Stage 03 — `03-swayfx.sh`

**What.** Install SwayFX from AUR. The `swayfx` package replaces `sway`
(it provides the same binary name). After this, `swaymsg -t get_version`
reports "swayfx".

```bash
paru -S --needed --noconfirm --useask --noprovides swayfx
```

> Why no `sudo pacman -R sway`: the AUR `swayfx` package conflicts with
> and replaces `sway`. `paru --useask` lets pacman resolve that package
> swap without a separate manual remove step. `--noprovides` selects the
> exact `swayfx` package instead of prompting between `swayfx`,
> `swayfx-git`, and other providers.
> See [REFERENCES.md §SwayFX](REFERENCES.md) for the upstream notes.

**Validation**:

```bash
swaymsg -t get_version >/dev/null 2>&1                 || exit 1
sway --version 2>/dev/null | grep -qi swayfx \
  || pacman -Q swayfx                                  || exit 1
[ -f /usr/share/wayland-sessions/swayfx.desktop ] \
  || [ -f /usr/share/wayland-sessions/sway.desktop ]   || exit 1
```

---

### Stage 04 — `04-session.sh`

**What.** Tools needed for a usable session: launcher, notification
daemon, Python IPC helpers, XDG portals (with the gtk + wlr split),
polkit agent autostart.

```bash
sudo pacman -S --needed --noconfirm \
  fuzzel mako \
  python-i3ipc \
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk

mkdir -p ~/.config/xdg-desktop-portal
cat > ~/.config/xdg-desktop-portal/portals.conf <<'EOF'
[preferred]
default=gtk
org.freedesktop.impl.portal.Screenshot=wlr
org.freedesktop.impl.portal.ScreenCast=wlr
EOF
```

**Validation**:

```bash
command -v fuzzel    || exit 1
command -v mako      || exit 1
python -c 'import i3ipc' || exit 1
[ -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ] || exit 1
```

---

### Stage 05 — `05-bars.sh`  ← **two waybars: status + pinned + taskbar**

**What.** Install waybar, the top-clock calendar popup, and the icon font
it relies on. The two configs (`top.jsonc` for status, `bottom.jsonc`
for pinned launchers + taskbar) are applied in stage 10.

```bash
sudo pacman -S --needed --noconfirm waybar otf-font-awesome
paru -S --needed --noconfirm waycal
```

**Validation**:

```bash
{ waybar --help 2>&1 || true; } | grep -q -- '--config' || exit 1
pacman -Qi waybar | grep -q 'Architecture' || exit 1
command -v waycal || exit 1
```

---

### Stage 06 — `06-utils.sh`

**What.** Utilities used in autostart or via keybind: clipboard manager,
screenshots, brightness, network, bluetooth, Tailscale remote access,
blue-light filter, audio GUI, JSON helper for waybar custom modules,
optional firewall, and ASUS power management.

```bash
sudo pacman -S --needed --noconfirm \
  wl-clipboard cliphist \
  grim slurp satty \
  brightnessctl gammastep \
  wdisplays pavucontrol playerctl \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  swayidle libnotify \
  jq ufw tailscale

sudo systemctl enable --now \
  NetworkManager.service bluetooth.service tailscaled.service
visudo -cf system/sudoers.d/90-tailscale-operator
sudo install -Dm 0440 system/sudoers.d/90-tailscale-operator \
  /etc/sudoers.d/90-tailscale-operator

paru -S --needed --noconfirm asusctl
sudo systemctl start asusd.service
busctl set-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform PlatformProfileLinkedEpp b true
busctl set-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ChangePlatformProfileOnAc b true
busctl set-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ChangePlatformProfileOnBattery b true
busctl set-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ProfileBalancedEpp u 3
busctl set-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ProfileQuietEpp u 4
asusctl profile set -a Balanced
asusctl profile set -b Quiet
asusctl battery limit 92
# Re-apply Balanced or Quiet last according to the current power source.
asusctl profile set <current-source-profile>
```

> `ufw` is installed but **not** enabled. The user enables it explicitly
> after defining rules.
> `tailscaled.service` is always enabled and running. The installer never
> runs `up`, `down`, `login`, or supplies an auth key. Tailscale issue #18294
> prevents a pre-login operator preference from working reliably, so stage 10
> stows a `tailscale` wrapper and stage 06 installs a `sudoers` rule restricted
> to `tailscale up --operator=joel` and `tailscale set --operator=joel`.
> Nothing is elevated until the user runs Tailscale. The second command repairs
> profiles created manually via `login`. Plain `tailscale up` first requires
> an HTTP `2xx` or `401` from the local OpenCode health endpoint, then connects, runs
> `tailscale serve reset`, proxies the configured localhost port at HTTPS root,
> and enables Tailscale SSH. Plain `tailscale down` resets Serve, disables SSH,
> and disconnects. The wrapper exclusively owns this node's Serve config.
> Serve must stay at URL root because OpenCode emits absolute `/assets` paths.
> Restrict custom Tailscale SSH policies to `joel`.
> `asusctl` is required on this ASUS target. Its static `asusd.service` is
> started, not enabled: package udev/D-Bus integration activates it later.
> `asusd` exclusively owns platform profile and linked EPP selection
> (`Balanced` / `BalancePower` on AC, `Quiet` / `Power` on battery) and
> persists the 92% charge limit. Stage 06 explicitly converges the automatic
> source-switching flags and EPP mappings, then reapplies the profile for the
> current source because each source-specific setter also activates its value.
> The stage-02 helper owns the disjoint CPU
> ceiling/boost, USB autosuspend, and Bluetooth settings, so event ordering
> cannot create a writer race.

**Validation**:

```bash
nmcli -t -f STATE general | grep -q 'connected\|disconnected'  || exit 1
brightnessctl get >/dev/null                                    || exit 1
grim /tmp/_test.png && rm -f /tmp/_test.png                     || exit 1
command -v jq                                                    || exit 1
command -v ufw                                                   || exit 1
command -v tailscale                                             || exit 1
systemctl is-enabled tailscaled.service                          || exit 1
systemctl is-active tailscaled.service                           || exit 1
sudo visudo -cf /etc/sudoers.d/90-tailscale-operator             || exit 1
systemctl is-active asusd.service                                || exit 1
asusctl profile get | grep -qx 'AC profile Balanced'             || exit 1
asusctl profile get | grep -qx 'Battery profile Quiet'           || exit 1
test "$(busctl get-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform PlatformProfileLinkedEpp)" = 'b true' || exit 1
test "$(busctl get-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ChangePlatformProfileOnAc)" = 'b true' || exit 1
test "$(busctl get-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ChangePlatformProfileOnBattery)" = 'b true' || exit 1
test "$(busctl get-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ProfileBalancedEpp)" = 'u 3' || exit 1
test "$(busctl get-property xyz.ljones.Asusd /xyz/ljones xyz.ljones.Platform ProfileQuietEpp)" = 'u 4' || exit 1
asusctl battery info | grep -qx 'Current battery charge limit: 92%' || exit 1
# The stage also derives the current power source, validates Active profile,
# and requires every CPU EPP node to match balance_power (AC) or power (battery).
```

---

### Stage 07 — `07-apps.sh`

**What.** Daily-driver GUI apps + TUI utilities + archive backends used
by file-roller / thunar-archive-plugin under the hood, plus the Mermaid
CLI for rendering local diagrams.

```bash
sudo pacman -S --needed --noconfirm \
  nautilus loupe papers gnome-text-editor gnome-calculator \
  file-roller mpv \
  mission-center btop tree htop \
  unzip zip p7zip tar \
  mermaid-cli

standard_brave=()
declare -A seen_standard_brave=()
for pkg in brave-bin brave-beta-bin brave-nightly-bin brave-browser; do
  actual_pkg="$(pacman -Qq "$pkg" 2>/dev/null || true)"
  if [[ -n "$actual_pkg" && -z "${seen_standard_brave[$actual_pkg]:-}" ]]; then
    standard_brave+=("$actual_pkg")
    seen_standard_brave[$actual_pkg]=1
  fi
done
if (( ${#standard_brave[@]} > 0 )) && confirm "Remove standard Brave?"; then
  paru -Rns --noconfirm "${standard_brave[@]}"
fi

if confirm "Delete old standard Brave profile/cache/launchers?"; then
  rm -rf ~/.config/BraveSoftware/Brave-Browser \
         ~/.cache/BraveSoftware/Brave-Browser \
         ~/.config/brave-flags.conf \
         ~/.local/share/applications/brave-*.desktop
fi

paru -S --needed --noconfirm brave-origin-bin

if [ -e ~/.config/BraveSoftware/Brave-Origin-Beta ] && [ ! -e ~/.config/BraveSoftware/Brave-Origin ]; then
  mv ~/.config/BraveSoftware/Brave-Origin-Beta ~/.config/BraveSoftware/Brave-Origin
fi
if [ -e ~/.cache/BraveSoftware/Brave-Origin-Beta ] && [ ! -e ~/.cache/BraveSoftware/Brave-Origin ]; then
  mv ~/.cache/BraveSoftware/Brave-Origin-Beta ~/.cache/BraveSoftware/Brave-Origin
fi
if [ -e ~/.config/BraveSoftware/Brave-Origin-Beta-Dev ] && [ ! -e ~/.config/BraveSoftware/Brave-Origin-Dev ]; then
  mv ~/.config/BraveSoftware/Brave-Origin-Beta-Dev ~/.config/BraveSoftware/Brave-Origin-Dev
fi
for mime in text/html x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about x-scheme-handler/unknown; do
  xdg-mime default brave-origin.desktop "$mime"
done
paru -Rns --noconfirm brave-origin-beta-bin brave-origin-nightly-bin 2>/dev/null || true
```

> `brave-origin-bin` is the release Brave Origin package used by Brave's
> upstream Linux installer on Arch (`FLAVOR=origin`). Existing Beta profile
> and cache directories are renamed to the release names before removing the
> preview package, so browser data is preserved.
>
> Nautilus is preferred per the user's stack. Thunar is the lighter
> alternative; if RAM becomes a problem, swap by replacing `nautilus`
> with `thunar gvfs tumbler thunar-volman thunar-archive-plugin` here.

**Validation**:

```bash
command -v nautilus  || exit 1
command -v brave-origin || exit 1
command -v mpv       || exit 1
command -v btop      || exit 1
command -v missioncenter || exit 1
command -v 7z        || exit 1
command -v mmdc      || exit 1
```

---

### Stage 08 — `08-theming.sh`

**What.** OS-level dark theme: GTK 3, GTK 4 / libadwaita, Qt, cursor,
icons, fonts. The actual color palette of waybar/mako/etc. lives in
their own configs (CONTEXT §4.1) — this stage only provides the
dependencies that those configs need.

```bash
sudo pacman -S --needed --noconfirm \
  adw-gtk-theme papirus-icon-theme \
  qt6ct kvantum nwg-look \
  ttf-firacode-nerd ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji inter-font

paru -S --needed --noconfirm bibata-cursor-theme

gsettings set org.gnome.desktop.interface color-scheme        'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme           'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme          'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme        'Bibata-Modern-Classic'
gsettings set org.gnome.desktop.interface font-name           'Inter 12'
gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font Mono 12'

fc-cache -fv
```

**Validation**:

```bash
[ "$(gsettings get org.gnome.desktop.interface color-scheme)" = "'prefer-dark'" ] || exit 1
fc-match 'FiraCode Nerd Font'       | grep -qi 'FiraCode'     || exit 1
fc-match 'JetBrainsMono Nerd Font'  | grep -qi 'JetBrains'    || exit 1
fc-match 'Inter'                    | grep -qi 'Inter'        || exit 1
```

---

### Stage 09 — `09-lock-power.sh`

**What.** Lock screen with effects, idle daemon already provided by
stage 06, power menu, physical power-key policy, UPower 5% suspend policy,
zram, and zram-focused sysctl tuning.

```bash
sudo pacman -S --needed --noconfirm zram-generator
curl -fsSL https://github.com/ArtsyMacaw.gpg | gpg --import || true
paru -S --needed --noconfirm swaylock-effects wlogout

sudo install -m 0644 "$ROOT/system/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm 0644 "$ROOT/system/sysctl.d/99-swayfx-zram.conf" /etc/sysctl.d/99-swayfx-zram.conf
sudo install -Dm 0644 "$ROOT/system/systemd/logind.conf.d/10-swayfx-power-key.conf" /etc/systemd/logind.conf.d/10-swayfx-power-key.conf
sudo install -Dm 0644 "$ROOT/system/UPower/UPower.conf.d/50-swayfx-battery.conf" /etc/UPower/UPower.conf.d/50-swayfx-battery.conf
sudo systemctl daemon-reload
sudo sysctl --load /etc/sysctl.d/99-swayfx-zram.conf
sudo systemctl restart systemd-zram-setup@zram0.service
sudo systemctl restart upower.service
```

> Reboot or restart `systemd-logind.service` after installing the drop-in so
> `HandlePowerKey=ignore` takes effect. The Sway config binds `XF86PowerOff`
> to `~/.local/bin/swayfx-powermenu`.

`system/zram-generator.conf`:

```ini
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
```

`system/sysctl.d/99-swayfx-zram.conf`:

```conf
vm.swappiness = 180
vm.page-cluster = 0
```

**Validation**:

```bash
{ swaylock --help 2>&1 || true; } | grep -q -- '--screenshots' || exit 1
command -v wlogout                              || exit 1
zramctl | grep -q zram0                         || exit 1
sysctl -n vm.swappiness | grep -qx 180          || exit 1
sysctl -n vm.page-cluster | grep -qx 0          || exit 1
grep -q '^HandlePowerKey=ignore$' /etc/systemd/logind.conf.d/10-swayfx-power-key.conf || exit 1
grep -qx 'PercentageAction=5.0' /etc/UPower/UPower.conf.d/50-swayfx-battery.conf || exit 1
```

---

### Stage 10 — `10-final.sh`

**What.** Apply all dotfiles via `stow -R`, run the acceptance checklist
([CONTEXT §10](CONTEXT.md)).

```bash
cd "$ROOT"
PKGS=( sway waybar ghostty fuzzel mako swaylock wlogout
       gtk environment gammastep mpv colors
       starship zsh scripts )

# Conflict detection first (writes to log; does not write to disk)
for p in "${PKGS[@]}"; do
  [ -d "$p" ] || continue
  if ! stow -n -v --target "$HOME" "$p" 2>>"$LOG_FILE"; then
    log_warn "conflicts detected in $p; backing up"
    backup_conflicts "$p"
  fi
done

# Real apply
for p in "${PKGS[@]}"; do
  [ -d "$p" ] || { log_warn "skip $p (does not exist)"; continue; }
  stow -R --target "$HOME" "$p"
done

xdg-user-dirs-update
fc-cache -fv

# Run checklist
bash "$ROOT/scripts/install/lib/checks.sh"
```

The `lib/checks.sh` walks the [§10 acceptance checklist](CONTEXT.md) and
prints `✓` / `✗` per item. Exits non-zero if any `✗`.

---

### Stage 99 — `99-greetd.sh`  ← **optional, manual**

**What.** Replace TTY1 + `.zprofile` with a graphical login via greetd +
ReGreet on cage. Run **only** after the rest of the install is stable.

```bash
sudo pacman -S --needed --noconfirm greetd greetd-regreet cage

sudo install -m 0644 "$ROOT/system/greetd.toml" /etc/greetd/config.toml
sudo install -m 0644 "$ROOT/system/regreet.toml" /etc/greetd/regreet.toml
sudo install -m 0644 "$ROOT/system/pam.d/greetd" /etc/pam.d/greetd

sudo systemctl disable getty@tty1.service || true
sudo systemctl enable greetd.service
```

`system/greetd.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "dbus-run-session cage -s -mlast -- regreet"
user = "greeter"
```

`system/pam.d/greetd` must not include `pam_securetty.so`; ReGreet
authenticates through greetd without a classic PAM_TTY item, and
`pam_securetty` can return `SERVICE_ERR` before user auth completes.

After enabling, **comment** the `exec sway` block in `~/.zprofile` so
TTY1 no longer races greetd.

**Validation**:

```bash
command -v regreet                          || exit 1
command -v cage                             || exit 1
! grep -Eq '^[[:space:]]*auth[[:space:]].*pam_securetty' /etc/pam.d/greetd || exit 1
ls /usr/share/wayland-sessions/             || exit 1
```

> This stage is **not** part of `--all`. Run with
> `./scripts/install/run.sh --only 99`.

---

### Optional fingerprint overlay — ELAN `04f3:0c90`

**What.** Enable fingerprint-first auth only for ReGreet and
swaylock-effects after the reader has been proven reliable with
`fprintd-verify`. This is not a numbered stage because the ASUS
`ELAN:ARM-M4` reader requires an experimental libfprint branch and not
every target install has this hardware.

Known-good local package path:

```bash
cd /home/joel/Descargas/libfprint-elanmoc2-0c90-git
sudo pacman -U ./libfprint-elanmoc2-0c90-git-1.94.0+372+g11f0316-1-x86_64.pkg.tar.zst
# When pacman asks whether to remove official libfprint, answer: s
sudo pacman -S --needed fprintd
sudo udevadm hwdb --update
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl restart fprintd.service
```

Enroll and verify before touching PAM:

```bash
fprintd-delete "$USER" 2>/dev/null || true
sudo systemctl stop fprintd.service
sudo /home/joel/Descargas/libfprint-elanmoc2-0c90-git/src/build/examples/clear-storage || true
sudo systemctl start fprintd.service
fprintd-enroll -f right-index-finger "$USER"
fprintd-verify -f right-index-finger "$USER"
```

Apply the per-service PAM overlays:

```bash
ts="$(date +%Y%m%d-%H%M%S)"
sudo cp -a /etc/pam.d/greetd "/etc/pam.d/greetd.bak.$ts"
sudo cp -a /etc/pam.d/swaylock "/etc/pam.d/swaylock.bak.$ts"
sudo install -Dm 0644 "$ROOT/system/pam.d/greetd-fingerprint" /etc/pam.d/greetd
sudo install -Dm 0644 "$ROOT/system/pam.d/swaylock-fingerprint" /etc/pam.d/swaylock
sudo systemctl restart fprintd.service
```

Do **not** edit `/etc/pam.d/system-auth` for this laptop by default.
`pam_fprintd.so` is serialized; ReGreet and swaylock cannot ask for
password and fingerprint at the exact same time. The templates try the
fingerprint first, then fall back to password after success, failure or
timeout.

**Validation**:

```bash
pacman -Q fprintd libfprint-elanmoc2-0c90-git || exit 1
fprintd-list "$USER" | grep -q right-index-finger || exit 1
fprintd-verify -f right-index-finger "$USER" || exit 1
grep -q pam_fprintd.so /etc/pam.d/greetd || exit 1
grep -q pam_fprintd.so /etc/pam.d/swaylock || exit 1
```

Rollback if the reader becomes flaky:

```bash
sudo cp -a /etc/pam.d/greetd.bak.<timestamp> /etc/pam.d/greetd
sudo cp -a /etc/pam.d/swaylock.bak.<timestamp> /etc/pam.d/swaylock
```

---

## 3. Critical config snippets (for the agent that will write the configs)

These are decisions the agent writing the dotfiles must respect. The
files themselves are not yet committed.

### 3.1. `sway/.config/sway/config` — key directives

```sway
# Verified against: https://github.com/WillPower3309/swayfx
# Reviewed: 2026-08-24

# === Pure-black palette ===
set $bg          #000000
set $surface     #0e0e10
set $surface_alt #15151a
set $border      #1f1f24
set $text        #e6e6e6
set $tab_text_dim #a6a6a6
set $accent      #89b4fa
set $focus_border #ffffaa
set $crit        #f38ba8

# Adjacent 2 px title borders form a 4 px black gutter between compact tabs.
font pango:JetBrainsMono Nerd Font Propo Bold 12
client.focused           $bg $border  #ffffff $bg $focus_border
client.focused_inactive  $bg $surface $tab_text_dim $bg $border
client.focused_tab_title $bg $border  #ffffff
client.unfocused         $bg $surface $tab_text_dim $bg $surface
client.urgent            $bg $crit    #ffffff $bg $crit

# === SwayFX visuals ===
default_border       pixel 3
smart_borders        no
default_floating_border pixel 3
floating_modifier    $mod normal
focus_follows_mouse  no
focus_on_window_activation focus
gaps inner           6
gaps horizontal      1
gaps vertical        1
# Keep a lone tiled/tabbed group flush to the workspace when maximized.
smart_gaps           on
corner_radius        10
titlebar_border_thickness 2
titlebar_padding      4 3
title_align           center
titlebar_separator    enable
show_marks            no

for_window [app_id="com.mitchellh.ghostty"] title_format "Ghostty - %title"
for_window [app_id="org.gnome.Nautilus"] title_format "Archivos - %title"
# The resident placement daemon normalizes Brave, VS Code, and Text Editor
# titles because those applications already append their product name.
shadows              disable
default_dim_inactive 0.075
dim_inactive_colors.unfocused #000000FF

# Shadows stay disabled globally for GPU/battery savings.

# DEVIATION: wlogout uses layer blur to make the power menu feel modal.
# The rest of the layer-shell UI stays unblurred.
layer_effects "wlogout" {
  blur enable
  shadows disable
}
blur_passes 3
blur_radius 5

# Blur ONLY on the terminal
blur                 disable
for_window [app_id="com.mitchellh.ghostty"]    blur enable
for_window [app_id="com.mitchellh.ghostty"]    blur_passes 3
for_window [app_id="com.mitchellh.ghostty"]    blur_radius 5
for_window [app_id="com.mitchellh.ghostty"]    opacity set 0.85
# The placement daemon switches tiled/tabbed Ghostty to 1.0 so its native
# title strip is opaque, then restores 0.85 when it returns to floating.

# Disable blur for graphics editors (color accuracy)
for_window [app_id="^gimp.*$"]                 blur disable, opacity set 1.0
for_window [class="^krita.*$"]                 blur disable, opacity set 1.0
for_window [app_id="org.inkscape.Inkscape"]    blur disable, opacity set 1.0
for_window [app_id="com.obsproject.Studio"]    blur disable, opacity set 1.0
for_window [app_id="virt-manager"]             blur disable, opacity set 1.0
for_window [app_id="mpv"]                      blur disable, opacity set 1.0

# === Dynamic floating-window policy ===
# Atomically replace the resident watcher/daemon so reload uses current code.
exec_always ~/.local/bin/swayfx-daemon-watch --replace ~/.local/bin/swayfx-placement-daemon

# === Native refresh-rate policy ===
# Uses only modes advertised by swaymsg -t get_outputs.
exec_always sh -c 'sleep 1; exec "$HOME/.local/bin/swayfx-refresh-rate" --once'
exec_always ~/.local/bin/swayfx-daemon-watch ~/.local/bin/swayfx-refresh-rate --watch

# === "Desktop-like" behavior ===
# DEVIATION: upstream marks scratchpad_minimize as experimental.
# We enable it because it is the only way to get true minimize-from-CSD.
# If quirks appear, disable it and accept activation without minimize.
scratchpad_minimize  enable
for_window [app_id=".*"] floating enable, resize set 1000 600
for_window [class=".*"] floating enable
# Brave is auto-maximized by swayfx-placement-daemon on window::new.

bindsym $mod+m            move scratchpad
bindsym $mod+Shift+m      scratchpad show
bindsym $mod+Shift+f      fullscreen toggle
bindsym $mod+f            exec ~/.local/bin/swayfx-maximize
bindsym $mod+w            exec ~/.local/bin/swayfx-placement-daemon --tabbed
# bindsym $mod+v splitv  # Fibonacci owns split orientation
# bindsym $mod+c splith
bindsym $mod+Shift+b      exec ~/.local/bin/swayfx-waybar-bottom-toggle

# === Two waybars ===
exec_always pkill -x waybar; \
  waybar -c ~/.config/waybar/top.jsonc    -s ~/.config/waybar/top.css & \
  waybar -c ~/.config/waybar/bottom.jsonc -s ~/.config/waybar/bottom.css &

# Outputs are intentionally not hardcoded.
# Discover with:  swaymsg -t get_outputs
output * bg ~/.config/sway/wallpaper.png fill
```

### 3.2. `waybar/.config/waybar/top.jsonc`

```jsonc
// Verified against: waybar(5), waybar-clock(5), waybar-battery(5), waybar-sway-workspaces(5)
// Reviewed: 2026-08-23
{
  "layer":        "top",
  "position":     "top",
  "fixed-center": true,
  "expand-left":  true,
  "expand-right": true,
  "height":       32,
  "spacing":      0,

  "modules-left":   ["custom/distro", "sway/workspaces", "sway/mode"],
  "modules-center": ["clock"],
  "modules-right":  ["network", "pulseaudio", "battery",
                     "custom/cpucap", "custom/touchpad", "custom/gammastep",
                     "custom/notifications", "custom/power"],

  "custom/distro":   { "format": "󰣇", "tooltip": false, "on-click": "fuzzel" },
  "sway/workspaces": { "format": "{name}", "disable-scroll": true,
                        "sort-by-number": true, "all-outputs": false },
  "clock":           { "format": "<b>{:%H:%M}</b>", "tooltip": false,
                        "on-click": "bash ~/.local/bin/swayfx-waycal-toggle" }
  // Status module details live in the deployed top.jsonc.
}
```

### 3.3. Shared pill style

`waybar/.config/waybar/_pill.css` — single source of truth for the two
bottom-bar group surfaces:

```css
#launchers, #windows {
  background: #0e0e10;
  border: 1px solid #1f1f24;
  border-radius: 18px;
  color: #e6e6e6;
  padding: 0 8px;
  margin: 0 3px;
}
```

### 3.4. `waybar/.config/waybar/top.css`

```css
* {
  font-family: "JetBrainsMono Nerd Font Propo", "JetBrainsMono Nerd Font",
               "Symbols Nerd Font", "Inter", sans-serif;
  font-size: 16px;
  font-weight: 700;
  border: none;
  min-height: 0;
}
window#waybar { background: #000000; color: #cdd6f4; }

#workspaces button             { color: #6c7086; border-radius: 14px; }
#workspaces button.active      { background: #89b4fa; color: #1e1e2e; }
#workspaces button.urgent      { background: #f38ba8; color: #1e1e2e; }
#battery.warning   { color: #f9e2af; }
#battery.critical  { color: #f38ba8; }
```

### 3.5. `waybar/.config/waybar/bottom.jsonc`

```jsonc
{
  "layer":         "top",
  "position":      "bottom",
  "height":        64,
  "spacing":       0,
  "margin-bottom": 4,
  "exclusive":     false,

  "modules-left":   [],
  "modules-center": ["group/launchers", "group/windows"],
  "modules-right":  [],

  "group/launchers": {
    "orientation": "horizontal",
    "modules": ["custom/terminal", "custom/browser", "custom/files"]
  },
  "group/windows": {
    "orientation": "horizontal",
    "modules": ["wlr/taskbar", "sway/scratchpad"]
  },

  "custom/terminal": { "format": "", "on-click": "ghostty",
                        "tooltip": true, "tooltip-format": "Terminal" },
  "custom/browser":  { "format": "", "on-click": "swayfx-browser",
                        "tooltip": true, "tooltip-format": "Brave Origin" },
  "custom/files":    { "format": "", "on-click": "nautilus",
                        "tooltip": true, "tooltip-format": "Archivos" },
  "wlr/taskbar": {
    "format":          "{icon}",
    "icon-size":       28,
    "all-outputs":     false,
    "active-first":    true,
    "icon-theme":      ["Papirus-Dark", "Papirus"],
    "tooltip-format":  "{name}: {title}",
    "on-click":        "minimize-raise",
    "on-click-right":  "maximize",
    "on-click-middle": "close"
  },
  "sway/scratchpad": {
    "format":         "{icon} {count}",
    "format-icons":   ["", ""],
    "show-empty":     false,
    // Global across all Sway workspaces and outputs.
    "tooltip-format": "{app}: {title}",
    "on-click":       "swaymsg scratchpad show"
  }
}
```

### 3.6. `waybar/.config/waybar/bottom.css`

```css
@import url("_pill.css");
* { font-family: "JetBrainsMono Nerd Font"; font-size: 15px;
    border: none; min-height: 0; }
window#waybar { background: transparent; }

#launchers, #windows { margin: 8px 3px; padding: 0 6px; border-radius: 26px; }
#custom-terminal, #custom-browser, #custom-files, #custom-editor {
  background: transparent; border: none; margin: 0 3px; padding: 0 4px;
}
#taskbar, #scratchpad { background: transparent; border: none; margin: 0; }
#taskbar { padding: 0 2px; }
#scratchpad { padding: 0 8px; }
#taskbar button { margin: 4px; padding: 4px; border-radius: 26px; background: transparent; border: 1px solid transparent; }
#taskbar button.active { background: rgba(255, 255, 170, 0.15); }
#taskbar button.fullscreen, #taskbar button.maximized { border-color: #a6e3a1; }
#taskbar button.minimized { opacity: 0.65; }
```

### 3.7. `starship/.config/starship.toml`

```toml
# Verified against: https://starship.rs/config/
# Reviewed: 2026-05-12
add_newline = true
scan_timeout = 30
command_timeout = 200
format = "$directory$git_branch$git_status$nodejs$python$rust$golang$cmd_duration\n$character"

[character]
success_symbol = "[>](bold #a6e3a1)"
error_symbol   = "[>](bold #f38ba8)"
vimcmd_symbol  = "[<](bold #89b4fa)"

[directory]
format            = "[ $path]($style)[$read_only]($read_only_style) "
truncation_length = 3
truncate_to_repo  = true
style             = "bold #89b4fa"

[git_branch]
symbol = " "
style  = "#f9e2af"

[git_status]
format     = '([\[ ](#9a9aa6)$all_status$ahead_behind[\]](#9a9aa6) )'
modified   = "[✱${count}](#89b4fa) "
staged     = "[+${count}](#a6e3a1) "
untracked  = "[?${count}](#f9e2af) "

[cmd_duration]
min_time          = 2000
style             = "#9a9aa6"
show_milliseconds = false
```

### 3.9. `zsh/.zshrc`

```bash
# Verified against: ArchWiki "zsh"
# Reviewed: 2026-05-10
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt INC_APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

autoload -U colors && colors
autoload -U compinit && compinit

# Plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh         2>/dev/null

# Prompt
eval "$(starship init zsh)"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
```

### 3.10. `zsh/.zprofile`

```bash
# Verified against: ArchWiki "Sway" → "Autostart on login"
# Reviewed: 2026-05-10
emulate sh -c 'source /etc/profile'

# Auto-start SwayFX on TTY1
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" = "1" ]; then
  export XDG_CURRENT_DESKTOP=sway
  export XDG_SESSION_TYPE=wayland
  export XDG_SESSION_DESKTOP=sway
  exec sway
fi
```

---

## 4. Repository script tree

```
scripts/install/
├── run.sh
├── lib/
│   ├── common.sh
│   ├── pkg.sh
│   └── checks.sh
└── stages/
    ├── 00-preflight.sh
    ├── 01-shell.sh
    ├── 02-base.sh
    ├── 03-swayfx.sh
    ├── 04-session.sh
    ├── 05-bars.sh
    ├── 06-utils.sh
    ├── 07-apps.sh
    ├── 08-theming.sh
    ├── 09-lock-power.sh
    ├── 10-final.sh
    └── 99-greetd.sh
```

`scripts/.local/bin/`:

```
scripts/.local/bin/
├── powermenu              # invoked by wlogout or $mod+Shift+e
├── screenshot-full        # grim → ~/Pictures
├── screenshot-area        # grim -g "$(slurp)" → ~/Pictures + satty
├── swayfx-daemon-watch    # restart/replace wrapper for user IPC daemons
├── swayfx-placement-daemon # placement + tabbed layout + border policy
├── swayfx-refresh-rate    # 60 Hz on AC, 48 Hz on battery when native
├── swayfx-maximize        # floating maximize/restore toggle
├── swayfx-waycal-toggle   # opens/closes the top-clock calendar popup
├── tailscale              # first-profile operator bootstrap wrapper
└── wallpaper-pick         # optional: change wallpaper via fuzzel
```

---

## 5. Recommended implementation order

Each session ends with a stage validated and the laptop in a known-good
state. Do not advance until the prior session passes its checklist.

1. **Session 1**: write `scripts/install/lib/common.sh`, `run.sh`,
   `00-preflight.sh`, `01-shell.sh`. Run `--only 00` then `--only 01`.
2. **Session 2**: write `02-base.sh`. After it passes, smoke-test vanilla
   Sway from TTY1 manually.
3. **Session 3**: write `03-swayfx.sh` + `04-session.sh`. Confirm
   SwayFX + fuzzel + mako boot to a usable session.
4. **Session 4**: write `05-bars.sh`. Iterate `top.jsonc`/`bottom.jsonc`
   + their CSS by applying with `stow waybar` manually until the look
   matches the reference image.
5. **Session 5**: write `06-utils.sh` + `07-apps.sh`. Validate wifi,
   brightness, audio, screenshots.
6. **Session 6**: write `08-theming.sh`. Verify Nautilus and
   gnome-calculator render dark.
7. **Session 7**: write `09-lock-power.sh`. Test `swaylock`, `wlogout`,
   `zram`.
8. **Session 8**: write `10-final.sh`. Run `--all` end-to-end on a fresh
   shell. If any item in the checklist fails, fix the responsible stage
   and re-run with `--from NN`.
9. **Session 9 (optional)**: write `99-greetd.sh` only if the user
   explicitly wants graphical login.

---

## 6. Files to create later (not in this commit)

When the user asks to implement, create the following respecting all
decisions in CONTEXT.md and the snippets above:

- `scripts/install/run.sh` and `lib/{common,pkg,checks}.sh`.
- `scripts/install/stages/{00..10}-*.sh` and optionally `99-greetd.sh`.
- `sway/.config/sway/config` (rewrite the current one with the new
  pure-black palette).
- `waybar/.config/waybar/{_pill.css, top.jsonc, top.css, bottom.jsonc,
  bottom.css}` (replace the current `config.jsonc`).
- `ghostty/.config/ghostty/config`.
- `fuzzel/.config/fuzzel/fuzzel.ini`.
- `mako/.config/mako/config`.
- `swaylock/.config/swaylock/config`.
- `wlogout/.config/wlogout/{layout, style.css}`.
- `gtk/.config/gtk-{3.0,4.0}/{settings.ini, gtk.css}`.
- `environment/.config/environment.d/sway.conf`.
- `gammastep/.config/gammastep/config.ini`.
- `mpv/.config/mpv/{mpv.conf, scripts/uosc.lua}`.
- `colors/.config/colors/blacked.conf` (replaces
  `catppuccin-mocha.conf`).
- `starship/.config/starship.toml`.
- `zsh/{.zshrc, .zprofile, .zshenv}`.
- `scripts/.local/bin/swayfx-browser`.
- `scripts/.local/bin/swayfx-cpu-cap`.
- `scripts/.local/bin/swayfx-refresh-rate`.
- `scripts/.local/bin/tailscale`.
- `system/usr/local/lib/swayfx-dotfiles/cpu-frequency-limit`,
  `system/systemd/system/swayfx-cpu-frequency-limit.service`,
  `system/udev/rules.d/90-swayfx-cpu-frequency-limit.rules`,
  `system/zram-generator.conf`, `system/sysctl.d/99-swayfx-zram.conf`,
  `system/systemd/logind.conf.d/10-swayfx-power-key.conf`,
  `system/sudoers.d/90-tailscale-operator`, `system/greetd.toml`.
- `.stow-local-ignore` at repo root, listing
  `^README\.md$`, `^AGENTS\.md$`, `^\.claude/`, `^\.git/`, `^old/`,
  `^scripts/install/`, `^system/`.

Every config gets a header:

```
# Verified against: <upstream URL>
# Reviewed: YYYY-MM-DD
```
