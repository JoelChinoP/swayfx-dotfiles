# CONTEXT.md — Canonical Project Specification

> **This is the source of truth.** When `PLAN.md`, `STACK.md`, `REFERENCES.md`,
> `AGENTS.md`, `README.md` or any code in this repo contradicts this file,
> **this file wins**. If anything is ambiguous, leave a `TODO:` and explain why
> instead of guessing.
>
> Last reviewed: 2026-05-10.

---

## 1. Who and what

- **User**: Joel.
- **Hardware**: ASUS laptop · AMD Ryzen 7 7730U · iGPU Vega 8 · 12 GB RAM.
- **Distro**: Arch Linux (with AUR).
- **Idle RAM target**: < 600 MB after login, no apps running. The
  estimated baseline (see [STACK §6](STACK.md)) is ~470 MB; the 130 MB
  headroom exists on purpose so that we never trade off
  stability/functionality (the bottom waybar, `nm-applet`,
  `polkit-gnome`) just to shave a few MB.
- **Language policy**:
  - Repository-level docs (this file, `PLAN.md`, `AGENTS.md`, `README.md`,
    code comments, commit messages, scripts) → **English**.
  - User-facing strings inside configs (notification messages, tooltips,
    waybar custom labels) → **Spanish**, since this is a personal laptop.

## 2. First-boot premises (Arch minimal already installed)

This project does **not** install Arch from scratch. It expects a working
Arch system with the items below. The exact `pacstrap` recipe lives in
[STACK.md §1](STACK.md). Stage `00-preflight` validates these and aborts
with a clear message if any is missing:

- Kernel + firmware: `linux`, `linux-firmware`, `sof-firmware`, `amd-ucode`
  (with bootloader regenerated so `/amd-ucode.img` is loaded before the
  initramfs). Without microcode the 7730U has known instabilities.
- `sudo` installed; user belongs to `wheel`, `video`, `input`, `audio`,
  `storage`, `power`; `%wheel ALL=(ALL:ALL) ALL` uncommented.
- Persistent network from TTY: **`NetworkManager.service` enabled** (or
  `iwd` if the user prefers — but the rest of this plan assumes NM).
- Time: `timedatectl set-timezone <Region/City>` + `systemd-timesyncd`
  active. Without sync, pacman/paru reject signatures.
- Locale: `/etc/locale.gen` with the chosen UTF-8 line uncommented;
  `locale-gen` ran; `/etc/locale.conf` with `LANG=…`.
- TTY: `/etc/vconsole.conf` with `KEYMAP=<layout>` (so TTY is not US QWERTY).
- Pacman: mirrors sorted with `reflector`; `Color`, `ParallelDownloads = 5`
  enabled in `/etc/pacman.conf`; `[multilib]` enabled in case Steam/Wine
  becomes relevant later.
- Tooling pre-installed by `pacstrap` (see STACK.md): `base-devel`, `git`,
  `stow`, `zsh`, `starship`, `nano`/`neovim`, `man-db`, `less`, `curl`/
  `wget`, `openssh`, `lm_sensors`, `jq`, archive
  utilities, hardware diagnostics, EFI tooling, filesystem progs.

## 3. What "desktop-style SwayFX" means

The user wants Sway's tiling efficiency **without losing the gestures of a
conventional desktop**:

- Maximize / minimize / move in window mode for any app, not only tiling.
- Tile and split when desired (Sway defaults).
- Top bar: clock · battery · wifi · audio · notifications · power button.
- Bottom bar: pinned launchers + active windows (taskbar, **always
  visible**, not autohidden).

Mapping to SwayFX features:

| Conventional concept   | Implementation                                               |
|------------------------|--------------------------------------------------------------|
| Minimize               | `scratchpad_minimize enable` + `wlr/taskbar` left click      |
| Maximize               | `fullscreen toggle` keybind + `wlr/taskbar` right click      |
| Window mode            | `floating toggle` (`$mod+Shift+space`) + `for_window` rules  |
| Close from bar         | `wlr/taskbar` middle click                                   |
| Tile / split           | Sway defaults (`splith`, `splitv`, `tabbed`, `stacking`)     |
| Top bar                | Waybar instance with `top.jsonc` + `top.css`                 |
| Bottom bar             | **Second Waybar instance** with `bottom.jsonc` + `bottom.css`|

> **Upstream warning about `scratchpad_minimize`**: the SwayFX README says
> "we recommend keeping this setting off, as there are many kinks to iron
> out here." We enable it on purpose — it is the only way to get true
> minimize-from-CSD — but if quirks appear (lost windows, wrong workspace
> on restore), the fallback is: leave it `disable` and rely solely on
> `wlr/taskbar` raise/lower behavior.

## 4. Aesthetic

### 4.1. Palette: pure / near-pure black (NOT Catppuccin)

This **overrides** any older note in this repo or in references that says
Catppuccin. The project uses a neutral very-dark palette:

| Role            | Hex       | Use                                           |
|-----------------|-----------|-----------------------------------------------|
| `--bg`          | `#000000` | bar background, compositor background         |
| `--surface`     | `#0e0e10` | pill background, module background            |
| `--surface-alt` | `#15151a` | hover, scratchpad, secondary panes            |
| `--border`      | `#1f1f24` | subtle pill border, focused window border     |
| `--text`        | `#e6e6e6` | primary text                                  |
| `--text-dim`    | `#9a9aa6` | secondary text, inactive icons                |
| `--accent`      | `#89b4fa` | active workspace, focused border              |
| `--ok`          | `#a6e3a1` | OK states (battery charging)                  |
| `--warn`        | `#f9e2af` | warning                                       |
| `--crit`        | `#f38ba8` | critical (battery < 15 %, urgent windows)     |

> "Near-pure" means the bar background may be `#000000` or `#0a0a0a`.
> The hard rule is **no blue/purple tints** like Catppuccin. Accents may
> reuse Catppuccin hexes, but they must not dominate.

### 4.2. Top bar (visual reference)

Inspired by a screenshot with three floating pills (round distro logo on
the left, workspace pills in the center, status pills on the right):

- Floating bar: `margin-top: 6px`, `margin-left/right: 10px`.
- **Bar background: transparent** (`rgba(0,0,0,0)`).
- Each module group is a **pill**: `padding: 4px 12px`,
  `background: --surface`, `border: 1px solid --border`,
  `border-radius: 18px`.
- **Pill spacing**: 8 px.
- Icons: JetBrainsMono Nerd Font 10. Text: Inter 10.
- Distro pill (left): perfect circle, Arch glyph.
- Active workspace pill: `--accent` background, `--bg` text.

### 4.3. Bottom bar

- Same pill style; **two centered pills**, do not span full width.
- Pill 1 (left): pinned launchers as `custom/*` modules.
- Pill 2 (right): `wlr/taskbar` with active windows (icons only,
  `icon-size: 22`).
- Initial pinned apps: terminal, browser, files, editor.
- Click left = minimize/restore; click right = maximize; click middle =
  close (on `wlr/taskbar`).
- `margin-bottom: 6px`. `exclusive: false` so floating windows can pass
  underneath.

### 4.4. Blur, opacity, shadows, corners

- **Blur**: only on the terminal. Other apps stay opaque and unblurred.
- **Opacity**: only on the terminal, **0.85** (do not drop to 0.75 — text
  becomes hard to read on light backgrounds behind it).
- **Shadows**: disabled (no visible benefit on a pure-black UI; saves GPU
  on Vega 8).
- **Corners**: `corner_radius 10`.
- **Borders**: `default_border pixel 2`, `smart_borders on`.
- Per-window blur **disabled** for graphics editors (gimp, krita,
  inkscape, OBS, mpv, virt-manager) so colors are not distorted while
  editing. Pattern from the [vaelixd reference](REFERENCES.md).

## 5. Stack

Full package list lives in [STACK.md](STACK.md). Top-level choices:

- **Compositor**: SwayFX (AUR).
- **Session start**: TTY1 + `exec sway` in `~/.zprofile`. **No display
  manager** in the main path. Optional Stage 9 sets up `greetd` + ReGreet
  for users who want a graphical login later.
- **Shell**: zsh + starship + plugins (`zsh-completions`,
  `zsh-syntax-highlighting`, `zsh-autosuggestions`). Installed **first**.
- **Terminal**: Ghostty (preferred). `foot` is installed early as fallback
  while testing TTY → Sway, then Ghostty becomes default.
- **Terminal font**: FiraCode Nerd Font Mono 11. The Nerd Font variant is
  required so Starship's folder/git icons render correctly. Waybar keeps
  JetBrainsMono Nerd Font for compact status icons.
- **Launcher**: fuzzel.
- **Notifications**: mako.
- **Bars**: two waybar instances (top: status; bottom: pinned + taskbar).
- **Lock**: `swaylock-effects` (AUR).
- **Idle**: `swayidle`.
- **Power menu**: `wlogout`. Lightweight fallback: `fuzzel --dmenu` script.
- **Wallpaper**: `swaybg`. Pure-black if no image set.
- **Audio**: `pipewire`/`wireplumber`/`pipewire-pulse` + `pavucontrol`.
  Requires `sof-firmware` (premise §2).
- **Network**: NetworkManager + `nm-applet` in tray.
- **Bluetooth**: bluez/bluez-utils + blueman-applet.
- **AMD drivers**: `mesa`, `vulkan-radeon`, `libva-utils`. Arch's
  `mesa` package provides the VA-API Mesa driver on current repos;
  `mesa-vdpau` is no longer available. Requires `amd-ucode`
  (premise §2).
- **Power management**: `cpupower` plus a project systemd/udev helper.
  Battery caps CPU scaling max at 2 GHz; AC caps it at 3 GHz. This is
  deliberately frequency-only, not TDP tuning.
- **Do not use power policy daemons in the main path**: no
  `power-profiles-daemon`, no `tlp`, no `auto-cpufreq`, no `ryzenadj`.
- **Sensors**: `lm_sensors` + `sensors-detect --auto` so waybar's
  temperature module has data.
- **ASUS-specific (optional)**: `asusctl` (AUR) for Fn keys.
  `supergfxctl` does not apply (7730U is iGPU-only).
- **Clipboard**: `wl-clipboard` + `cliphist`.
- **Screenshots**: `grim` + `slurp` + `satty` (official repo).
- **Brightness**: `brightnessctl`.
- **Blue-light filter**: `gammastep`.
- **File manager**: Nautilus (preferred per user's stack note). Thunar is
  a lighter alternative if RAM is tight.
- **Browser**: `brave-bin` (AUR) with Wayland + VAAPI flags.
- **Editor**: `gnome-text-editor`.
- **PDF**: `papers`.
- **Images**: `loupe`.
- **Calculator**: `gnome-calculator` (floating).
- **Multimedia**: `mpv` + `uosc` + `hwdec=auto-safe`.
- **Archive backends**: `unzip`, `zip`, `p7zip`, `tar`, `file-roller`,
  `thunar-archive-plugin` (used regardless of Nautilus vs Thunar).
- **Resource monitors**: `mission-center` (official repo, GUI), `btop` (TUI).
- **Custom-module helper**: `jq`.
- **Firewall (optional)**: `ufw`. Installed **inactive**; user enables it
  after setting their own rules.
- **zram**: `zram-generator`, 4 GB, zstd, priority 100, with
  `vm.swappiness=180` and `vm.page-cluster=0` for compressed-RAM swap
  under Docker/container pressure.

## 6. Implementation philosophy

### 6.1. Stage by stage, small to big

Installation is split into numbered **stages**. Each stage:

1. Does **one cohesive thing** (one cluster of packages or configs).
2. Validates at the end with copy-pasteable commands.
3. **Stops the chain** if validation fails.
4. Is **idempotent**: running it twice does not break anything (relies on
   `--needed`, `stow -R`, `mkdir -p`, presence checks).

### 6.2. Master script + per-stage scripts

```
scripts/install/
├── run.sh              # master entrypoint
├── lib/
│   ├── common.sh       # logging, helpers (info, warn, die, run, confirm)
│   ├── pkg.sh          # paru/yay/pacman wrappers
│   └── checks.sh       # post-stage validation helpers
└── stages/
    ├── 00-preflight.sh         # validate Arch minimal premises
    ├── 01-shell.sh             # zsh + starship + plugins (FIRST)
    ├── 02-base.sh              # sway + drivers + audio + sensors + cpupower
    ├── 03-swayfx.sh            # replace sway with SwayFX (AUR)
    ├── 04-session.sh           # fuzzel + mako + xdg portals + polkit
    ├── 05-bars.sh              # waybar (two instances)
    ├── 06-utils.sh             # clipboard, screenshots, brightness, NM, BT
    ├── 07-apps.sh              # GUI apps + TUI utilities + archive backends
    ├── 08-theming.sh           # GTK/Qt dark, fonts, cursor, icons
    ├── 09-lock-power.sh        # swayidle, swaylock-effects, wlogout, zram
    └── 10-final.sh             # stow everything + run final checklist
```

Optional stage (do **not** include in `--all`):

- `99-greetd.sh` — graphical login via greetd + ReGreet + cage. Run
  manually only after the rest is stable.

CLI:

```
./scripts/install/run.sh [--all] [--from NN] [--only NN] [--list]
                         [--dry-run] [--yes]
```

- `--list` prints the stages and exits.
- `--from 04` resumes from stage 04.
- `--only 03` runs only stage 03.
- `--all` runs every stage in order (the default if no flag given is
  prompt-then-`--all`).
- `--dry-run` propagates `DRY_RUN=1` to every stage; nothing is written.
- `--yes` skips the initial confirmation prompt.

### 6.3. Script contract

- All scripts start with `set -euo pipefail` and `IFS=$'\n\t'`.
- All scripts source `lib/common.sh` for logging.
- Logs append to `~/swayfx-dotfiles-install.log`.
- Per-stage state in `~/.local/state/swayfx-dotfiles/stages/<NN>.done`.
- Backups of pre-existing files in
  `~/.local/share/swayfx-dotfiles/backups/<timestamp>/`.
- A failing stage exits non-zero; the master aborts the chain.
- No `sudo` mid-script. Each stage that needs root runs `sudo -v` at the
  very top and refreshes the timestamp; the user enters the password once.
- No `cp` for dotfiles inside scripts; **always** `stow -R`.
- No destructive ops (`rm -rf`, `pacman -R --no-confirm`) without explicit
  user confirmation flag.

### 6.4. Dotfile application: GNU Stow

- The repo is structured as Stow packages (`sway/`, `waybar/`, `foot/`,
  `ghostty/`, `fuzzel/`, `mako/`, `swaylock/`, `wlogout/`, `gtk/`,
  `environment/`, `gammastep/`, `mpv/`, `brave/`, `colors/`, `starship/`,
  `zsh/`, `scripts/`).
- The repo includes a `.stow-local-ignore` so Stow does not symlink
  `*.md`, `.git`, `.claude`, `system/`, `scripts/install/`, `old/`.
- `10-final.sh` runs `stow -R --target "$HOME" <pkg>` for each existing
  package, skipping empty placeholders.
- A `--simulate` pass first detects conflicts and writes them to the log;
  conflicting files are backed up before `stow` overwrites the path.

### 6.5. When a stage fails

- Do **not** patch the next stage; fix the failing one.
- Read the last `[ERROR]`/`[FATAL]` line in
  `~/swayfx-dotfiles-install.log`.
- Resume with `./scripts/install/run.sh --from NN`.

## 7. Repo layout (target)

```
swayfx-dotfile/
├── README.md                        # English, user-facing
├── AGENTS.md                        # English, agent entry point
├── .gitignore
├── .stow-local-ignore
├── .claude/
│   ├── CONTEXT.md                   # this file (English, canonical)
│   ├── PLAN.md                      # staged plan (English)
│   ├── STACK.md                     # package list / tool choices
│   ├── REFERENCES.md                # reference repo analysis + SwayFX upstream
│   └── settings.local.json
├── scripts/
│   ├── install/
│   │   ├── run.sh
│   │   ├── lib/{common,pkg,checks}.sh
│   │   └── stages/{00..10}-*.sh
│   └── .local/bin/                  # powermenu, screenshot helpers
├── sway/.config/sway/config
├── waybar/.config/waybar/{top,bottom}.{jsonc,css}
├── foot/.config/foot/foot.ini
├── ghostty/.config/ghostty/config
├── fuzzel/.config/fuzzel/fuzzel.ini
├── mako/.config/mako/config
├── swaylock/.config/swaylock/config
├── wlogout/.config/wlogout/{layout,style.css}
├── gtk/.config/{gtk-3.0,gtk-4.0}/{settings.ini,gtk.css}
├── environment/.config/environment.d/sway.conf
├── gammastep/.config/gammastep/config.ini
├── mpv/.config/mpv/{mpv.conf,scripts/uosc.lua}
├── brave/.config/brave-flags.conf
├── colors/.config/colors/blacked.conf
├── starship/.config/starship.toml
├── zsh/{.zshrc,.zprofile,.zshenv}
├── system/                          # /etc + /usr/local system templates
└── (legacy files: PLAN.codex.md, planv2.codex.md, etc. — to be removed)
```

## 8. Naming conventions

- Shell variables: `UPPER_SNAKE`.
- Bash functions: `verb_object`, `snake_case`.
- Stage files: `NN-short-name.sh` (NN = two digits, leading zero).
- Section headers in configs: `# ──── Section ────`.
- Verification line at the top of every config:
  `# Verified against: <upstream URL> · Reviewed: YYYY-MM-DD`.

## 9. Hard rules ("don't do this")

- **Do not** mix Catppuccin Mocha or any non-black palette into the bars
  or compositor surfaces. The palette is §4.1.
- **Do not** use `nwg-dock` for the bottom bar. Use a second waybar
  instance with pinned `custom/*` + `wlr/taskbar`.
- **Do not** drop terminal opacity below `0.85`.
- **Do not** install `swaylock` (official) alongside `swaylock-effects`
  (AUR) — they conflict. Stick to `swaylock-effects`.
- **Do not** enable `shadows`. The plain-black UI does not benefit and
  Vega 8 takes the cost.
- **Do not** install `power-profiles-daemon`, `tlp` or `auto-cpufreq`
  in the main path. CPU policy is handled by the project cpupower helper.
- **Do not** install `ryzenadj` in the main path. CPU frequency ceilings
  use `cpupower`; RyzenAdj is only for explicit low-level TDP experiments.
- **Do not** auto-enable `ufw`. Install it disabled; user enables it
  after defining their own ruleset.
- **Do not** copy configs with `cp` from the install scripts. Always
  `stow -R`.
- **Do not** advance past a stage whose validation failed.
- **Do not** skip stage `00-preflight`. Stages 01+ assume premises §2.
- **Do not** hardcode output names (`eDP-1`, `HDMI-A-1`); use `output *`
  and document how to query with `swaymsg -t get_outputs`.
- **Do not** hardcode battery names (`BAT0`/`BAT1`) without a comment
  pointing to `/sys/class/power_supply` for adjustment.
- **Do not** introduce a display manager in the main path. greetd is
  optional.
- **Do not** apply blur or opacity to layer-shell surfaces (waybar, mako,
  swaybg). They stay opaque/transparent as configured by their own CSS.
- **Do** annotate every deviation from upstream with `# DEVIATION:`
  followed by the rationale.

## 10. Acceptance checklist (final, after `10-final.sh`)

Grouped so a failure points to the responsible stage.

### 10.1. Premises (§2 / stage 00)

- [ ] `pacman -Q amd-ucode sof-firmware sudo` → all installed.
- [ ] `systemctl is-active NetworkManager` → `active`.
- [ ] `systemctl is-active systemd-timesyncd` → `active`.
- [ ] `localectl status | grep "System Locale"` → expected `LANG=`.
- [ ] `cat /proc/cmdline` shows `amd-ucode.img` (or equivalent).

### 10.2. Session and compositor (stages 01–05)

- [ ] Logging in on TTY1 starts SwayFX automatically via `~/.zprofile`.
- [ ] `swaymsg -t get_version | grep -i swayfx` → SwayFX active.
- [ ] `pgrep -a waybar | wc -l` → 2.
- [ ] Top bar visible, transparent background, pure-black pills.
- [ ] Bottom bar visible: pinned apps + active windows.
- [ ] Pinned apps launch terminal, browser, files, editor.
- [ ] Left click on active window minimizes/restores; right maximizes;
      middle closes.
- [ ] `$mod+f` toggles fullscreen; `$mod+Shift+space` toggles floating.
- [ ] Terminal blurred and at 0.85 opacity; everything else opaque.

### 10.3. Hardware and services (stages 02 / 06 / 09)

- [ ] `vainfo` reports `VAEntrypointVLD` for H264 and HEVC.
- [ ] `wpctl status` lists sink and source.
- [ ] `sensors` reports CPU temperature (lm_sensors configured).
- [ ] `systemctl is-enabled swayfx-cpu-frequency-limit` → `enabled`.
- [ ] On battery, CPU `scaling_max_freq` is at or below `2000000`; on AC,
      at or below `3000000`.
- [ ] `notify-send "test" "ok"` displays a notification.
- [ ] `brightnessctl set +5%` changes brightness.
- [ ] `nmcli device status` lists wifi; the top bar reflects it.
- [ ] `bluetoothctl show` reports the controller.
- [ ] `swaylock -f` locks with blur over the screenshot.
- [ ] `wlogout` opens the power menu.

### 10.4. Theming and shell (stages 01 / 08)

- [ ] `gsettings get org.gnome.desktop.interface color-scheme` →
      `'prefer-dark'`.
- [ ] `getent passwd $USER | grep -q '/zsh$'` → zsh is the login shell.
- [ ] Starship prompt visible in zsh (e.g. `›` arrow).
- [ ] zsh autosuggestions and syntax-highlighting active.
- [ ] `fc-list | grep -qi 'FiraCode.*Nerd'`,
      `'JetBrains.*Nerd'`, and `'Inter'` → fonts registered.

### 10.5. Resources (stage 09 / 10)

- [ ] `free -m` 30 s after login with no apps → < 600 MB used (target
      ~470 MB; ceiling 600 MB).
- [ ] `zramctl` shows `/dev/zram0` 4 GB zstd.
- [ ] `sysctl -n vm.swappiness` → `180`.
- [ ] `sysctl -n vm.page-cluster` → `0`.
- [ ] `~/swayfx-dotfiles-install.log` has no `[ERROR]` / `[FATAL]` lines.

## 11. Glossary

- **Stage**: one numbered script that performs a slice of the install and
  validates the result.
- **Pill**: a waybar module group with padding, background, border and
  border-radius that produces the visual reference design.
- **CSD** (Client-Side Decorations): the app draws its own
  close/maximize/minimize buttons; the alternative is SSD where the
  compositor draws them. SwayFX honors CSD.
- **wlr/taskbar**: waybar module that lists open toplevels via the
  `wlr-foreign-toplevel-management-unstable-v1` protocol.
- **scratchpad_minimize**: SwayFX setting that makes minimize requests
  (CSD button or IPC) move the window to the scratchpad. Marked
  experimental upstream; we enable it deliberately.
- **layer_effects**: SwayFX directive that applies blur/shadows/corner
  radius to layer-shell namespaces (e.g. waybar). We do **not** use blur
  here, but the directive is documented in case the user wants to enable
  it on swaylock or mako selectively.
