# REFERENCES.md — External Project Analysis & SwayFX Upstream Notes

> Research notes for the canonical decisions in [CONTEXT.md](CONTEXT.md)
> and [PLAN.md](PLAN.md). When upstream behavior changes, update this
> file with the new revision date and reflect the change in CONTEXT.
>
> Last reviewed: 2026-05-16.

---

## 1. SwayFX upstream — install and config

Source: <https://github.com/WillPower3309/swayfx> (README and Wiki).

### 1.1. Install on Arch

The upstream README does **not** publish an Arch install snippet (only
Nix, Debian, Docker, manual compile). The Arch path is via AUR:

- AUR package: `swayfx`. Provides and conflicts with `sway`. After
  installing `swayfx`, `swaymsg -t get_version` reports a SwayFX build
  string and the binary is the same `sway`.
- AUR variants seen in the wild: `swayfx-git` (HEAD), `swayfx-bin` does
  not exist at the time of this review.
- Build dependencies (used by paru when no `-bin` exists): `meson`,
  `wayland`, `wayland-protocols`, `pcre2`, `json-c`, `pango`, `cairo`,
  `wlroots`, `scenefx`, `gdk-pixbuf2`, `swaybg`, `scdoc`, `git`. Most
  come in via `base-devel`; `scenefx` is the SwayFX-specific dep and
  paru will pull it from AUR.

> Implication for our plan: stage 03 just runs `paru -S --needed swayfx`
> and lets paru handle the conflict swap. We never `pacman -R sway`
> ourselves.

### 1.2. Wayland session file

The package installs `/usr/share/wayland-sessions/sway.desktop` (it
reuses the `sway` session). A `swayfx.desktop` is **not** added by
upstream. greetd's session list will show "Sway" — that is correct and
will spawn the SwayFX binary.

### 1.3. Config directives we rely on (verbatim from upstream README)

```
# Blur
blur enable|disable
blur_xray enable|disable
blur_passes <integer 0-10>
blur_radius <integer 0-10>
blur_noise <float 0-1>
blur_brightness <float 0-2>
blur_contrast <float 0-2>
blur_saturation <float 0-2>

# Corners
corner_radius <val>

# Shadows
shadows enable|disable
shadows_on_csd enable|disable
shadow_blur_radius <integer 0-99>
shadow_color <hex with alpha>
shadow_offset <x> <y>
shadow_inactive_color <hex with alpha>

# Layer effects (apply effects to layer-shell namespaces like waybar)
layer_effects "<namespace>" {
  blur enable
  shadows enable
  corner_radius 20
}

# Dim inactive
default_dim_inactive <float 0.0-1.0>
dim_inactive <float 0.0-1.0>           # per-window
dim_inactive_colors.unfocused <hex>
dim_inactive_colors.urgent <hex>

# Scratchpad
scratchpad_minimize enable|disable
```

### 1.4. Upstream warnings

- **`scratchpad_minimize`**: README explicitly says
  *"we recommend keeping this setting off, as there are many kinks to
  iron out here."* We enable it on purpose — it is the only path to
  CSD-button minimize semantics — but the plan documents the fallback
  (`disable` and rely on `wlr/taskbar` raise/lower).
- **`smart_corner_radius`**: appears in some forks and old configs. The
  current upstream README does **not** list it. We do not use it.
- **`opacity` syntax**: in `for_window` blocks, both `opacity 0.85` and
  `opacity set 0.85` are accepted. The canonical form upstream (and what
  the vaelixd reference uses) is `opacity set <float>`. We use that.

### 1.5. `blur enable` vs `blur on`

Some references (e.g. vaelixd) use `blur on`. Upstream README only lists
`blur enable|disable`. Both work in current builds because of an
internal alias, but `enable|disable` is the documented form and we use
that.

---

## 2. Reference dotfiles projects

Five repos consulted; each evaluated for what we adopt and what we
reject.

### 2.1. `sotormd/nixos`

| Aspect          | Finding                                    |
|-----------------|--------------------------------------------|
| Compositor      | SwayFX                                     |
| Bar             | Waybar (status modules)                    |
| Bottom dock     | **Eww widgets**                            |
| Terminal        | Ghostty                                    |
| Launcher        | Rofi                                       |
| Notifications   | Dunst                                      |
| Theming         | Custom "colors" flake; dark-leaning        |
| Management      | NixOS flakes                               |

- **Adopt**: modular separation (modules → profiles → roles).
- **Reject**: NixOS-specific tooling (we are on Arch); Eww (RAM budget);
  Dunst (we use mako, which is the canonical choice for layer-shell
  notifications and lighter than Dunst on Wayland).

### 2.2. `elenapan/dotfiles`

| Aspect          | Finding                                    |
|-----------------|--------------------------------------------|
| Compositor      | SwayFX (described as "Sway with extras")   |
| Bar             | **Eww**, three-page sidebar                |
| Terminal        | Kitty                                      |
| Launcher        | Rofi                                       |
| Notifications   | Dunst + notify-send.sh                     |
| File manager    | nnn + Nemo                                 |
| Theming         | "Dark and cozy", custom fonts, kawaii      |
| Management      | Manual `cp`, configs split across files    |

- **Adopt**: split keybinds across files (better organization in `sway`
  config).
- **Reject**: Eww; aesthetic (we want minimal pure-black, not "kawaii");
  manual `cp` (we use Stow).

### 2.3. `vwv-source/dotfiles`

| Aspect          | Finding                                    |
|-----------------|--------------------------------------------|
| Compositor      | SwayFX                                     |
| Bar             | **Eww** (action center + bar)              |
| Terminal        | WezTerm                                    |
| Launcher        | rofi                                       |
| Notifications   | Dunst + tiramisu                           |
| Management      | One-liner `cp -r dotfiles/* ~/.config/`    |
| Status          | Archived read-only (June 2024)             |

- **Adopt**: nothing meaningful for our architecture.
- **Reject**: Eww; WezTerm (we use Ghostty); destructive one-liner install.

### 2.4. `Failedex/CarbonMonoxide`

| Aspect          | Finding                                    |
|-----------------|--------------------------------------------|
| Compositor      | SwayFX                                     |
| Bar             | **Eww** (animated bar + dock + widgets)    |
| Terminal        | Ghostty                                    |
| Launcher        | Wofi                                       |
| Lock            | Swaylock                                   |
| Theming         | Oxocarbon palette                          |
| Management      | **GNU Stow** with `.stow-local-ignore`     |
| Notable         | Touch-friendly, includes wvkbd-mobintl     |

- **Adopt**: GNU Stow + `.stow-local-ignore` pattern. Confirmed our
  decision.
- **Reject**: Eww; Oxocarbon palette; touch-keyboard (not relevant).

### 2.5. `vaelixd/SwayFX-Dotfiles`

| Aspect          | Finding                                    |
|-----------------|--------------------------------------------|
| Compositor      | SwayFX                                     |
| Bar             | Waybar + Eww calendar widget               |
| Terminal        | Kitty                                      |
| Launcher        | Rofi (Wayland)                             |
| Notifications   | SwayNC                                     |
| File manager    | Yazi                                       |
| Browser         | Librewolf with TextFox                     |
| Theming         | Catppuccin Mocha across the board          |
| Management      | bash install script + manual 10-step       |
| Lock            | Hyprlock (yes, on SwayFX — works)          |
| Wallpaper       | Waypaper                                   |

This is the only purely-SwayFX repo of the five. Concrete config
extracts that informed our plan:

```
corner_radius 15
blur on                     # we standardize on `blur enable`
blur_xray off
blur_passes 3
blur_radius 5
default_dim_inactive 0.17
dim_inactive_colors.unfocused #000000FF
dim_inactive_colors.urgent #900000FF
scratchpad_minimize disable  # !! they keep it OFF (heeding upstream)

# Global low opacity with per-app overrides
for_window [class=".*"]                          opacity set 0.8
for_window [app_id="gimp*"]                      opacity set 1.0
for_window [class="krita*"]                      opacity set 1.0
for_window [app_id="org.inkscape.Inkscape"]      opacity set 1.0
for_window [app_id="virt-manager"]               opacity set 1.0
for_window [app_id="com.obsproject.Studio"]      opacity set 1.0

# Blur disable for graphics tools
for_window [app_id="gimp*"]                      blur disable
for_window [class="krita*"]                      blur disable
for_window [app_id="org.inkscape.Inkscape"]      blur disable
for_window [app_id="virt-manager"]               blur disable
for_window [app_id="com.obsproject.Studio"]      blur disable
```

- **Adopt**: per-app blur+opacity disables for graphics editors. Added
  to [PLAN §3.1](PLAN.md).
- **Adopt**: the `dim_inactive_colors.unfocused #000000FF` line — gives
  an extra hint of separation between focused and unfocused on
  pure-black backgrounds.
- **Adopt-but-invert**: vaelixd opacifies *everything* and keeps
  graphics apps opaque. We do the **opposite** (everything opaque except
  the terminal). The graphics-app exceptions still apply because if the
  user later globalizes opacity, the graphics rules already exist.
- **Note**: vaelixd keeps `scratchpad_minimize disable` per upstream
  recommendation. We diverge — see CONTEXT §3 — and document the
  fallback.
- **Reject**: Catppuccin palette; SwayNC (we use mako, lighter);
  Waypaper (we use swaybg with a fixed image).

---

## 3. Cross-reference summary

| Decision in our plan          | Validated by                       | Rationale                                                   |
|-------------------------------|------------------------------------|-------------------------------------------------------------|
| GNU Stow                      | CarbonMonoxide                      | Idempotent, reversible, conflict-aware                      |
| Two waybar instances          | None of the references             | All five use Eww for the dock; we trade animations for RAM  |
| `wlr/taskbar` minimize-raise  | `man waybar-wlr-taskbar(5)`        | Canonical                                                   |
| Per-app blur disable          | vaelixd                            | Color accuracy in editors                                   |
| `dim_inactive_colors`         | vaelixd                            | Visual cue on a pure-black canvas                           |
| Pure-black palette (no CP)    | None — original to this repo       | User preference; references trend Catppuccin/Oxocarbon      |
| TTY1 + `.zprofile` exec sway  | ArchWiki "Sway" autostart section  | Lightest path, no DM RAM cost                               |
| greetd/ReGreet as **optional**| codex draft + ArchWiki             | Defer DM until session is stable                            |
| `cpupower` CPU ceilings       | cpupower manual + ArchWiki         | Simple 2 GHz battery / 3 GHz AC frequency cap without PPD/TLP |
| `scratchpad_minimize enable`  | (DEVIATION from upstream)          | Required for CSD-button minimize; fallback documented       |
| `swaylock-effects`            | All references                     | Real lock with screenshot+blur                              |
| `mako` (not Dunst, not SwayNC)| Sway/man pages                     | Canonical layer-shell notification daemon                   |

---

## 4. Things deliberately NOT borrowed

- **Eww widgets** for the bar/dock: 4 of 5 references use them, but Eww
  pulls in GTK + custom Lua and easily adds 80–120 MB to idle RAM. Our
  budget is < 600 MB total (target ~470 MB); spending a quarter on
  chrome is not viable.
- **Catppuccin Mocha** (Mocha or any variant): the pure-black design is
  intentionally neutral. Catppuccin-style purples would clash with the
  bar reference image.
- **Light-mode toggles**: dark-only is a hard requirement.
- **Hardcoded outputs / batteries / timezones**: all examples in
  references hardcode things like `eDP-1`, `BAT0`, `Europe/Madrid`. Our
  configs use generic forms with comments for adjustment.
- **One-line destructive installers**: `cp -r dotfiles/* ~/.config/ &&
  rm -rf dotfiles` (vwv-source) is brittle. We use staged `stow -R`.

---

## 5. Documentation pinned

- SwayFX: <https://github.com/WillPower3309/swayfx>
- Sway 5: `man 5 sway`
- Sway input: `man 5 sway-input`
- Waybar: `man 5 waybar`
- Waybar wlr/taskbar: `man 5 waybar-wlr-taskbar`
- Waybar sway/workspaces: `man 5 waybar-sway-workspaces`
- Waybar custom: `man 5 waybar-custom`
- Waybar clock / battery / network / pulseaudio / bluetooth / cpu /
  memory / temperature: same-named man pages.
- Ghostty: <https://ghostty.org/docs>
- fuzzel: `man 5 fuzzel.ini`
- mako: `man 5 mako`
- swaylock-effects: <https://github.com/jirutka/swaylock-effects>
- swayidle: `man 1 swayidle`
- nwg-dock (legacy reference): <https://github.com/nwg-piotr/nwg-dock>
- Starship: <https://starship.rs/config/>
- gammastep: <https://gitlab.com/chinstrap/gammastep>
- Brave Origin overview: <https://support.brave.app/hc/en-us/articles/38561489788173-What-is-Brave-Origin>
- Brave Origin Beta on Linux: <https://brave.com/origin/linux/beta/>
- Brave Origin Beta AUR: <https://aur.archlinux.org/packages/brave-origin-beta-bin>
- Brave Origin Beta AUR wrapper: <https://aur.archlinux.org/cgit/aur.git/plain/brave-origin-beta-bin.sh?h=brave-origin-beta-bin>
- Chromium VA-API flags: <https://chromium.googlesource.com/chromium/src/+/main/docs/gpu/vaapi.md>
- mpv: <https://mpv.io/manual/master/>
- uosc: <https://github.com/tomasklaen/uosc>
- GNU Stow: <https://www.gnu.org/software/stow/manual/stow.html>
- Arch installation: <https://wiki.archlinux.org/title/Installation_guide>
- Arch general recommendations: <https://wiki.archlinux.org/title/General_recommendations>
- Microcode: <https://wiki.archlinux.org/title/Microcode>
- Firmware: <https://wiki.archlinux.org/title/Firmware>
- PipeWire: <https://wiki.archlinux.org/title/PipeWire>
- NetworkManager: <https://wiki.archlinux.org/title/NetworkManager>
- zram: <https://wiki.archlinux.org/title/Zram>
- cpupower frequency limits: <https://man.archlinux.org/man/extra/cpupower/cpupower-frequency-set.1.en>
- power-profiles-daemon (rejected for main path): <https://wiki.archlinux.org/title/CPU_frequency_scaling>
- TLP processor settings (rejected for main path): <https://linrunner.de/tlp/settings/processor.html>
- RyzenAdj (deferred low-level TDP experiments only): <https://github.com/FlyGoat/RyzenAdj>
- greetd: <https://wiki.archlinux.org/title/Greetd>
- ReGreet: <https://github.com/rharish101/ReGreet>
- xdg-desktop-portal-wlr: <https://github.com/emersion/xdg-desktop-portal-wlr>
- XDG portals.conf: <https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html>
