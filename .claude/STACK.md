# STACK.md — Package Manifest and Tool Choices

> Derived from [CONTEXT.md §5](CONTEXT.md). When a package decision
> changes, update CONTEXT first, then mirror it here. Stages in
> [PLAN.md](PLAN.md) install from these lists.
>
> Last reviewed: 2026-05-12.

---

## 1. Pre-repo: Arch minimal `pacstrap`

This is the baseline the user installs from the Arch ISO **before**
cloning this repo. It satisfies all premises in CONTEXT §2.

```bash
pacstrap -K /mnt \
  base linux linux-firmware sof-firmware amd-ucode \
  networkmanager sudo git base-devel \
  zsh starship stow \
  lm_sensors jq \
  nano man-db man-pages texinfo \
  efibootmgr dosfstools \
  btrfs-progs exfatprogs ntfs-3g \
  pciutils usbutils lshw hwinfo inxi \
  reflector pacman-contrib openssh \
  curl wget rsync unzip zip p7zip
```

Stage 00 can repair missing official packages from this installer-critical
set (`base-devel`, `git`, `zsh`, `starship`, `stow`, `lm_sensors`, `jq`,
`curl`, `wget`, `openssh`, `unzip`, `zip`, `p7zip`, plus firmware and
NetworkManager). It still assumes a booted Arch system, a non-root target
user with working `sudo`, usable pacman repos, and network connectivity.

After `arch-chroot /mnt`:

```bash
ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime
hwclock --systohc
# Edit /etc/locale.gen, run: locale-gen
# Edit /etc/locale.conf, /etc/hostname, /etc/hosts
# Edit /etc/vconsole.conf (KEYMAP=...)
useradd -m -G wheel,video,input,audio,storage,power joel
passwd joel
EDITOR=nano visudo                # uncomment %wheel ALL=(ALL:ALL) ALL
systemctl enable NetworkManager.service systemd-timesyncd.service
# Install bootloader (systemd-boot or GRUB) — see ArchWiki
# IMPORTANT: ensure amd-ucode.img is loaded BEFORE initramfs in the
#            bootloader entry, e.g.:
#              initrd /amd-ucode.img
#              initrd /initramfs-linux.img
```

---

## 2. Per stage — what each script installs

The full per-stage breakdown lives in [PLAN.md §2](PLAN.md). This is the
flat manifest grouped by repo source for review.

### 2.1. Official repos (`pacman -S --needed`)

#### Stage 00 — preflight repair
```
linux-firmware sof-firmware amd-ucode
networkmanager git base-devel
zsh starship stow
lm_sensors jq curl wget openssh
unzip zip p7zip
```

#### Stage 01 — shell
```
zsh starship
zsh-completions zsh-syntax-highlighting zsh-autosuggestions
ttf-firacode-nerd ttf-jetbrains-mono-nerd inter-font
```

#### Stage 02 — base
```
sway swaybg ghostty
mesa vulkan-radeon libva-utils
pipewire wireplumber pipewire-pulse pipewire-jack
sof-firmware alsa-ucm-conf
xorg-xwayland qt5-wayland qt6-wayland
xdg-utils xdg-user-dirs polkit polkit-gnome
lm_sensors cpupower
```

#### Stage 04 — session
```
fuzzel mako
python-i3ipc
xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
```

#### Stage 05 — bars
```
waybar otf-font-awesome
```

#### Stage 06 — utils
```
wl-clipboard cliphist
grim slurp satty
brightnessctl gammastep
wdisplays pavucontrol playerctl
networkmanager network-manager-applet
bluez bluez-utils blueman
swayidle libnotify
jq ufw
```

#### Stage 07 — apps
```
nautilus loupe papers gnome-text-editor gnome-calculator
file-roller mpv
mission-center btop tree htop
unzip zip p7zip tar
```

> Lighter alternative for stage 07 if RAM is tight: replace `nautilus`
> with `thunar gvfs tumbler thunar-volman thunar-archive-plugin`.

#### Stage 08 — theming
```
adw-gtk-theme papirus-icon-theme
qt6ct kvantum nwg-look
ttf-firacode-nerd ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji inter-font
```

#### Stage 09 — lock & power
```
zram-generator
```

System tuning installed by the stage:

```
/etc/systemd/zram-generator.conf       # 4 GB zram, zstd, priority 100
/etc/sysctl.d/99-swayfx-zram.conf      # swappiness=180, page-cluster=0
```

#### Stage 99 — greetd (optional)
```
greetd greetd-regreet cage
```

### 2.2. AUR (`paru -S --needed`)

#### Stage 00 — preflight bootstrap
```
paru                  # AUR helper itself, only if not present
```

#### Stage 03 — SwayFX
```
swayfx
```

#### Stage 05 — bars
```
waycal                # top-clock calendar popup
```

#### Stage 06 — utils (optional)
```
asusctl               # ASUS Fn keys (optional, WARN on failure)
```

#### Stage 07 — apps
```
brave-bin
```

#### Stage 08 — theming
```
bibata-cursor-theme
```

#### Stage 09 — lock & power
```
swaylock-effects
wlogout
```

---

## 3. Why each tool and not another

Justifications for non-obvious choices. Update only with CONTEXT first.

### 3.1. Compositor: SwayFX (not Sway, not Hyprland)

- **Sway**: lacks blur, opacity, corner-radius, shadows. We want those.
- **Hyprland**: heavier on Vega 8, different config language, different
  IPC. The user explicitly chose SwayFX.
- **SwayFX**: drop-in replacement for Sway with the visual extras we
  need; same `.config/sway/config` syntax with extra directives.

### 3.2. Bars: two waybars (not nwg-dock, not Eww)

- **nwg-dock**: GTK launcher dock. Different CSS dialect. Default click
  is "launch/focus", not "minimize". Forces extra scripting.
- **Eww**: powerful but expensive (~80–120 MB idle). Breaks our budget.
- **Two waybar instances**: same engine, same CSS, same icons. Pinned
  apps via `custom/*` modules; active windows via `wlr/taskbar`. This
  matches the visual reference in one binary.
- **waycal**: small GTK4 layer-shell calendar popup launched by clicking
  the top bar clock. It avoids using a separate persistent calendar daemon.

### 3.3. Floating window IPC helpers

- **python-i3ipc**: small Python IPC library used by the SwayFX placement
  daemon to cascade new floating windows and apply border visibility
  policy without polling.

### 3.4. Notifications: mako (not Dunst, not SwayNC)

- **Dunst**: X-first; on Wayland it works through xdg-desktop-portal but
  feels less native and weighs more.
- **SwayNC**: heavy (notification panel + control center). We just want
  popups.
- **mako**: layer-shell native, ~6–10 MB, scriptable via `makoctl`.

### 3.5. Power management: cpupower helper (not PPD/TLP)

- **cpupower**: sets a hard CPU scaling maximum. The project caps the CPU
  at 2 GHz on battery and 3 GHz on AC via a systemd/udev helper.
- **power-profiles-daemon**: rejected for the main path. Without GNOME or
  Plasma power UI it adds little here, and the fixed cpupower ceiling is
  the actual policy the user wants.
- **TLP / auto-cpufreq**: rejected because they add another policy layer.
- **RyzenAdj**: deferred for explicit low-level TDP experiments only.

### 3.6. Display: TTY1 + `.zprofile` (greetd as optional)

- **No DM**: lowest RAM cost, simplest. Login on TTY1 fires Sway via
  `.zprofile`. Ideal until the rest of the desktop is stable.
- **greetd + ReGreet on cage**: optional stage 99. Run when the user
  wants a graphical login experience.
- **SDDM/GDM**: pulls in Qt or GTK + their dependencies; overkill for a
  single-user laptop.

### 3.7. Browser: Brave (not Firefox / not Chromium)

- **Brave**: ad-blocking by default; works well with VAAPI on Wayland;
  the user explicitly chose it. Pulls some Chromium dependencies.
- **Firefox**: viable, but the user has no preference between the two
  and Brave handles VAAPI + Wayland with simpler flags than Chromium.
- Flags live in `brave/.config/brave-flags.conf`:
  ```
  --ozone-platform-hint=auto
  --enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,AcceleratedVideoEncoder,WaylandWindowDecorations,VaapiIgnoreDriverChecks
  --enable-wayland-ime
  --password-store=basic
  --force-dark-mode
  --enable-features=WebUIDarkMode
  ```

### 3.8. Terminal: Ghostty

- **Ghostty** es el terminal principal. GPU rendering, soporte de temas,
  `gtk-single-instance = true`, formato de configuración maduro.
- `$mod+Return` lanza Ghostty.

### 3.9. File manager: Nautilus (preferred), Thunar (lighter alt)

- **Nautilus**: matches the user's stated preference; integrates well
  with GNOME apps (gnome-text-editor, papers, loupe).
- **Thunar**: ~1/3 the memory; honors CSD on SwayFX more cleanly. Swap
  in stage 07 if RAM becomes tight.

### 3.10. Lock: swaylock-effects (AUR), not swaylock

- Official `swaylock` works but does not blur. swaylock-effects adds
  `--screenshots`, `--effect-blur`, `--effect-pixelate`,
  `--effect-vignette`, and is what every reference uses.
- The two packages **conflict**. Install only `swaylock-effects`.

### 3.11. ZRAM tuning: zstd + 4 GB + aggressive zram use

- `zstd` keeps a good compression ratio without making the desktop feel
  CPU-bound.
- 4 GB is enough headroom for Docker/container memory pressure on a
  12 GB laptop without overcommitting the machine by default.
- `vm.swappiness=180` makes the kernel prefer compressed in-RAM swap
  before heavier reclaim.
- `vm.page-cluster=0` disables swap readahead, which is appropriate for
  memory-backed zram.

### 3.12. Resource monitors: mission-center + btop

- **mission-center**: GUI, GNOME-native, replaces gnome-system-monitor
  with a lighter footprint.
- **btop**: TUI bound to the cpu/memory waybar pills via
  `on-click: ghostty -e btop`.

---

## 4. Optional / deferred packages

Not part of stages 00–10 by default. Install manually when needed.

| Package           | Reason to install                                     |
|-------------------|-------------------------------------------------------|
| `docker`/-buildx  | container workflows                                   |
| `obs-studio`      | screen recording with VAAPI                           |
| `code`            | VS Code with `--ozone-platform=wayland`               |
| `bruno-bin` (AUR) | Postman replacement (~150 MB vs ~450 MB)              |
| `helvum`          | PipeWire patchbay GUI                                 |
| `playerctl`       | already in stage 06; mentioned for completeness       |
| `gnome-disk-utility` | partition / disk GUI                              |

---

## 5. Conflict matrix (do **not** install together)

| Group A             | Conflicts with             | Resolution                  |
|---------------------|----------------------------|-----------------------------|
| `swayfx`            | `sway` (official)          | Let paru replace `sway`.    |
| `swaylock-effects`  | `swaylock` (official)      | Install only the AUR one.   |
| `cpupower` policy helper | `power-profiles-daemon` / `tlp` / `auto-cpufreq` / `ryzenadj` | Stage 00 removes rejected policy layers when confirmed. |
| `pipewire-pulse`    | `pulseaudio`               | We use the pipewire stack.  |
| `pipewire-jack`     | `jack2`                    | We use pipewire's JACK.     |
| `wireplumber`       | `pipewire-media-session`   | wireplumber is current.     |

---

## 6. Idle RAM budget

**Target: < 600 MB.** Estimated baseline: ~470 MB. The 130 MB headroom
between the estimate and the ceiling exists so we never have to trade
stability or convenience for a few MB.

| Component                       | Estimated  |
|---------------------------------|-----------:|
| Kernel + base userland          | ~250 MB    |
| swayfx                          | ~25 MB     |
| waybar (top)                    | ~35 MB     |
| waybar (bottom)                 | ~30 MB     |
| mako                            | ~8 MB      |
| swayidle                        | ~5 MB      |
| swaybg                          | ~10 MB     |
| pipewire + wireplumber          | ~30 MB     |
| nm-applet + blueman-applet      | ~40 MB     |
| cliphist watchers               | ~10 MB     |
| polkit-gnome                    | ~20 MB     |
| gammastep                       | ~5 MB      |
| **Total estimated**             | **~470 MB**|

### 6.1. RAM is not performance

These components are **idle most of the time**: pollers run every 1–30 s
and DBus listeners are passive. CPU at idle is effectively 0 % and they
do not show up in latency or battery in normal use. The only resource
they consume meaningfully is RAM. Do **not** remove anything from the
list under the assumption that it will make the desktop "feel faster" —
it will not, and you will lose features.

### 6.2. If `free -m` exceeds 600 MB

Do **not** start cutting features. First investigate the cause:

```bash
ps_mem 2>/dev/null || sudo pacman -S --needed ps_mem
ps_mem | tail -30           # top consumers
systemd-cgtop -m            # by cgroup
```

Common real causes (fix these first, before touching the stack):

- A leaking app (Brave with many tabs, Electron app) is still running.
- `tracker3` indexer running its first scan after Nautilus install.
- A waybar custom module re-spawning on every interval (check the
  `exec:` field is not forking).

### 6.3. Last-resort cuts (only if a real overshoot is confirmed)

Ordered from "least painful to remove" to "do not touch unless cornered":

1. **`asusctl`** (if installed) — only useful for ASUS Fn keys.
2. **`blueman-applet`** — replace with `bluetoothctl` from a terminal
   keybind. Saves ~20 MB. Loses tray icon for quick toggle.
3. **`nm-applet`** — replace with waybar's `network` module
   (`on-click: nm-connection-editor`, `on-click-right: nmtui`). Saves
   ~25 MB. Loses tray icon and quick connection menu.
4. **`gammastep`** — only meaningful at night. Saves ~5 MB.
5. **`cliphist` watchers** — saves ~10 MB. Loses clipboard history.

**Do NOT remove these even under pressure** — they are stability and
core UX:

- The **bottom waybar**: it is the taskbar (minimize / maximize / close
  semantics). Removing it breaks the "desktop-style" goal entirely.
- **`polkit-gnome`**: GUI apps that need authorization (mounting,
  `nm-connection-editor`, software installers) silently fail without a
  polkit agent.
- **`pipewire-pulse` / `wireplumber`**: audio.
- **`mako`**: notifications. Without it, `notify-send` is a no-op.

### 6.4. Changing the ceiling

If you genuinely need to keep the bigger pieces and the measured idle
sits around 550–600 MB, **leave it**. Stability and ergonomics beat
shaving 50 MB on a 12 GB machine. Update [CONTEXT §1](CONTEXT.md) and
this section if the ceiling needs to move; do not silently start
removing components.
