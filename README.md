# swayfx-dotfile

Personal SwayFX desktop on Arch Linux for an ASUS laptop
(Ryzen 7 7730U · Vega 8 · 12 GB RAM). Dark-only, near-pure-black palette,
two-bar layout with pinned launchers and an active-windows taskbar.

> **AI agent?** Open [`AGENTS.md`](AGENTS.md) first.
> **Just curious?** Keep reading.

---

## Goals

- Sway's tiling efficiency **plus** conventional desktop ergonomics
  (minimize, maximize, close from a taskbar).
- A floating top bar with status pills (clock, battery, wifi, audio,
  notifications, power) and a floating bottom bar with pinned launchers
  + a `wlr/taskbar` of open windows.
- Dark **only**. Pure black `#000000` background, neutral grays, a small
  accent palette. No Catppuccin.
- Idle RAM under 600 MB (estimated ~470 MB after login, with 130 MB
  headroom kept on purpose so we never sacrifice stability for a few MB).
- Reproducible, staged install — every step validates before the next
  one runs.

## Layout

```
top:    [󰣇]  [1 2 3 …]  ········  [  85%]  [󰕾 60%]  [󰂀 72%]  [󰂚]  [󰐥]
bottom:                       [    ]  [   …running… ]
```

The top bar is transparent; each module group is a "pill" (rounded
rectangle, dark background, subtle border). The bottom bar shows a
pinned-apps pill (Ghostty / Brave Origin / Files / Editor) and a
`wlr/taskbar` pill with active window icons.

## Hardware target

| Component | Value                                  |
|-----------|----------------------------------------|
| Laptop    | ASUS                                   |
| CPU       | AMD Ryzen 7 7730U (Zen 3, 8c/16t)      |
| GPU       | iGPU AMD Radeon Vega 8                 |
| RAM       | 12 GB                                  |
| Distro    | Arch Linux (with AUR)                  |
| Session   | Wayland                                |

## How it gets installed

Installation is split into numbered **stages**:

| Stage | What it does                                                |
|------:|-------------------------------------------------------------|
| 00    | Validate/repair Arch minimal premises and power-policy conflicts |
| 01    | zsh + starship + plugins (first, before anything graphical) |
| 02    | Vanilla Sway + AMD drivers + audio + sensors + CPU power caps |
| 03    | Replace Sway with SwayFX from AUR                           |
| 04    | Launcher (fuzzel) + notifications (mako) + XDG portals       |
| 05    | Waybar (one binary, two configs)                             |
| 06    | Clipboard, screenshots, brightness, network, bluetooth, BT   |
| 07    | GUI apps (Nautilus, Brave Origin Beta, mpv, GNOME utilities, btop…) |
| 08    | Dark theming for GTK 3/4, Qt, cursor, icons, fonts           |
| 09    | swaylock-effects + wlogout + zram/sysctl tuning              |
| 10    | Apply all dotfiles via `stow -R` (incl. desktop overrides) and run the final checklist |
| 99    | (Optional) graphical login via greetd + ReGreet              |

Each stage has its own script in `scripts/install/stages/NN-*.sh` and
ends with copy-pasteable validation commands. The master
`scripts/install/run.sh` chains them and stops at the first failure.

> The staged installer and primary Stow configs are implemented. The
> detailed behavioral spec lives in [`.claude/PLAN.md`](.claude/PLAN.md);
> run real stages only on Arch, not from Ubuntu.

### Quick start (once the installer exists)

```bash
# 1. Have Arch minimal already installed (see .claude/STACK.md §1).
#    Stage 00 can repair missing installer-critical packages such as
#    base-devel, starship, stow, jq, unzip, zip and p7zip.
# 2. Clone the repo.
git clone https://github.com/<your-user>/swayfx-dotfile.git ~/swayfx-dotfile
cd ~/swayfx-dotfile

# 3. Preview which stages would run.
./scripts/install/run.sh --list

# 4. Dry-run, no writes.
./scripts/install/run.sh --all --dry-run

# 5. Run the full chain (asks for sudo once per stage that needs it).
./scripts/install/run.sh --all

# Resume from a specific stage after fixing a failure:
./scripts/install/run.sh --from 04
```

After the chain completes, log out and log back in on TTY1 — `~/.zprofile`
will start SwayFX automatically.

## Documentation

| File                                              | What's inside                                        |
|---------------------------------------------------|------------------------------------------------------|
| [`AGENTS.md`](AGENTS.md)                          | Entry point for AI agents                            |
| [`desktop-overrides/README.md`](desktop-overrides/README.md) | `.desktop` overrides — what each file changes and how to add more |
| [`.claude/CONTEXT.md`](.claude/CONTEXT.md)        | Canonical spec — palette, hardware, hard rules       |
| [`.claude/PLAN.md`](.claude/PLAN.md)              | Staged installation plan                             |
| [`.claude/STACK.md`](.claude/STACK.md)            | Package manifest, conflicts, RAM budget              |
| [`.claude/REFERENCES.md`](.claude/REFERENCES.md)  | Upstream research notes                              |

The Spanish-language drafts at the repo root
(`context.claude.md`, `context.codex.md`, `planv2.claude.md`,
`planv2.codex.md`, `StackSwayFx-Arch.md`) are **legacy work-in-progress**.
The English files in `.claude/` supersede them; once the installer is
written and tested, the legacy files will be removed.

## Default keybinds (preview)

| Combo                  | Action                              |
|------------------------|-------------------------------------|
| `Mod+Return`           | Open terminal                       |
| `Mod+d`                | Open fuzzel launcher                |
| `Mod+Shift+e`          | Open file manager                   |
| `Mod+q`                | Close window                        |
| `Mod+f`                | Toggle fullscreen                   |
| `Mod+Shift+space`      | Toggle floating                     |
| `Mod+m` / `Mod+Shift+m`| Send to / show scratchpad           |
| `Mod+h/j/k/l`          | Move focus                          |
| `Mod+Shift+h/j/k/l`    | Move window                         |
| `Mod+1..9`             | Switch workspace                    |
| `Mod+Shift+1..9`       | Move window to workspace            |
| `Mod+r`                | Resize mode                         |
| `Mod+Ctrl+l`           | Lock screen                         |
| `Mod+Ctrl+v`           | Clipboard history (cliphist+fuzzel) |
| `Print` / `Mod+Print`  | Screenshot full / region            |

Bottom-bar taskbar clicks: **left** = minimize/restore, **right** =
maximize, **middle** = close.

## License

Personal dotfiles. Do whatever you want with them; no warranty. If you
borrow ideas, a link back is appreciated but not required.
