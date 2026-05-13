# AGENTS.md — Entry point for AI agents working on this repo

> If you are an AI agent (Claude Code, Codex, Cursor, Aider, Copilot
> Workspace, etc.) opening this repository: **read this file first**, then
> the four files inside `.claude/`. Everything you need is there. Do not
> ask the user to re-explain context.
>
> Last reviewed: 2026-05-10.

---

## 0. What this repo is

A staged installer + dotfiles for **SwayFX on Arch Linux**, targeting an
ASUS laptop with Ryzen 7 7730U + Vega 8 + 12 GB RAM. The end result is a
dark-only Wayland desktop with two waybar pills (status + taskbar), a
pure-black palette, and conventional desktop ergonomics (minimize,
maximize, close from a taskbar) on top of Sway's tiling.

The installer is broken into numbered stages that validate at each step
and abort the chain on any failure. Configs are deployed via GNU Stow.

---

## 1. Read these files in this order

1. **[.claude/CONTEXT.md](.claude/CONTEXT.md)** — canonical spec.
   Hardware, palette, stack decisions, hard rules, glossary, acceptance
   checklist. **When this contradicts anything else, this wins.**
2. **[.claude/PLAN.md](.claude/PLAN.md)** — the staged installation plan
   (`00-preflight` → `10-final`, plus optional `99-greetd`). Each stage
   has commands, validation, and notes.
3. **[.claude/STACK.md](.claude/STACK.md)** — the per-stage package
   manifest, AUR vs official split, conflict matrix, idle-RAM budget,
   rationale for each tool choice.
4. **[.claude/REFERENCES.md](.claude/REFERENCES.md)** — research notes:
   the five upstream dotfiles repos consulted, what we adopted vs
   rejected, and verbatim SwayFX upstream config syntax.

The Spanish-language `context.claude.md`, `context.codex.md`,
`planv2.claude.md`, `planv2.codex.md` and `StackSwayFx-Arch.md` at the
repo root are **legacy drafts**. Treat them as historical context only;
the canonical English versions in `.claude/` supersede them.

---

## 2. Hard rules (the short list)

If you only remember six things, remember these. Full list in
[.claude/CONTEXT.md §9](.claude/CONTEXT.md):

1. **Palette is pure / near-pure black.** No Catppuccin. No purple
   tints. Hexes in CONTEXT §4.1.
2. **One stage = one script** in `scripts/install/stages/NN-*.sh`. Each
   exits non-zero on failure and the master stops the chain. Resumable
   with `--from NN`.
3. **Dotfiles deploy with `stow -R`**, not `cp`. The master script
   applies all packages in stage 10; only `01-shell` stows early.
4. **zsh + starship are stage 01** (before anything graphical). Stage
   01 also writes `~/.zprofile` with the TTY1 → `exec sway` block.
5. **Two waybars, never `nwg-dock`.** Bottom bar pinned launchers
   (`custom/*`) + active windows (`wlr/taskbar`).
6. **`scratchpad_minimize enable`** is a deliberate deviation from
   upstream's recommendation. Document it (`# DEVIATION:`) wherever you
   touch it. Fallback: disable and rely on `wlr/taskbar` raise/lower.

---

## 3. How to behave when implementing

- **Match scope to the request**. If the user asks for stage 02, do
  stage 02 — do not also rewrite stage 03.
- **Verify before recommending**. Before suggesting a package or
  directive, confirm it still exists with `pacman -Si` /
  `paru -Si <pkg>` or by reading the upstream README. Some references
  in this repo were verified at the date stamped in each `.md` file;
  re-verify if the date is older than ~30 days.
- **Header every config you write**:
  ```
  # Verified against: <upstream URL>
  # Reviewed: YYYY-MM-DD
  ```
- **Annotate every deviation**:
  ```
  # DEVIATION: <one-line rationale>
  ```
- **Do not** introduce new features, packages, or palettes without
  updating `.claude/CONTEXT.md` first.
- **Do not** delete the legacy Spanish `.md` files at the repo root
  unless the user asks. They are drafts the user is still reviewing.
- **Commit messages**: short, imperative, English. Example:
  `stage 02: install pipewire stack and amdgpu drivers`.
- **Do not** open PRs, push, or run destructive operations
  (`rm -rf`, `pacman -R`, force-push, branch deletes) without explicit
  confirmation from the user.

---

## 4. What you can do without asking

These actions are pre-authorized for an agent already in this repo:

- Read any file under the repo root.
- Create or edit files inside `.claude/`, `scripts/`, or any Stow
  package directory (`sway/`, `waybar/`, etc.).
- Run `stow -n -v <pkg>` (dry-run) to preview symlinks.
- Run `bash -n <file>` to syntax-check shell scripts.
- Run `swaymsg -t get_outputs`, `pacman -Si`, `paru -Si` (read-only).
- Run `fc-list`, `gsettings get`, `vainfo`, `wpctl status`, `sensors`,
  `nmcli device status` (read-only diagnostics).

These actions need explicit confirmation:

- `pacman -S`, `paru -S`, `pacman -R`, `paru -R`, anything `sudo`.
- `stow -R` (writes symlinks to `$HOME`).
- Any `systemctl enable` / `disable`.
- Anything that touches `/etc`.
- `git push`, `git reset --hard`, branch deletion, force-push.

---

## 5. Repo layout (target)

```
swayfx-dotfile/
├── README.md                # English, user-facing
├── AGENTS.md                # this file
├── .gitignore
├── .stow-local-ignore
├── .claude/
│   ├── CONTEXT.md           # canonical spec — read first
│   ├── PLAN.md              # staged installation plan
│   ├── STACK.md             # package manifest
│   ├── REFERENCES.md        # upstream research notes
│   └── settings.local.json
├── scripts/
│   ├── install/
│   │   ├── run.sh
│   │   ├── lib/{common,pkg,checks}.sh
│   │   └── stages/{00..10,99}-*.sh
│   └── .local/bin/          # powermenu, screenshot helpers
├── sway/.config/sway/config
├── waybar/.config/waybar/{_pill.css,top.jsonc,top.css,bottom.jsonc,bottom.css}
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
└── system/                  # /etc and /usr/local system templates
```

The Stow packages and stage scripts are implemented. Keep
[.claude/PLAN.md](.claude/PLAN.md) as the behavioral contract when
editing them.

---

## 6. Common tasks an agent will be asked

### "Implement stage NN"

1. Read [.claude/PLAN.md](.claude/PLAN.md) for stage NN.
2. Create `scripts/install/stages/NN-*.sh` matching the contract:
   - `set -euo pipefail`, `IFS=$'\n\t'`.
   - source `lib/common.sh`.
   - install commands wrapped in `run`.
   - validation block at the end; `exit 1` on failure.
3. Make it idempotent (`--needed`, `mkdir -p`, presence checks).
4. Annotate any deviation from upstream.
5. Do **not** apply user dotfiles in this stage (except stage 01 zsh +
   starship). All Stow happens in stage 10.

### "Write the config for X"

1. Confirm the design rules in CONTEXT (palette, fonts, blur policy).
2. Look at the snippet in [.claude/PLAN.md §3](.claude/PLAN.md) for X.
3. Place the file in `<pkg>/.config/<app>/<file>` (Stow layout).
4. Add the verification header.
5. Test by `stow -n -v <pkg>` (dry run) — confirm no conflicts.

### "Why does X fail?"

1. Check `~/swayfx-dotfiles-install.log` for the last `[ERROR]` /
   `[FATAL]` line.
2. Locate the failing stage in [.claude/PLAN.md](.claude/PLAN.md).
3. Check the validation block — that pinpoints the broken assumption.
4. Fix the cause; do not edit downstream stages to compensate.
5. Resume with `./scripts/install/run.sh --from NN`.

### "Add package X"

1. Justify it against the idle-RAM budget
   ([.claude/STACK.md §6](.claude/STACK.md)).
2. Update CONTEXT §5 (stack list) and STACK.md (manifest).
3. Add it to the appropriate stage in PLAN.md.
4. Update the relevant stage script.
5. Update the acceptance checklist if the new package introduces a
   service or user-visible feature.

---

## 7. Working language

- **Code, scripts, repo docs, commit messages, PR descriptions**:
  English.
- **In-config user-facing strings** (waybar tooltips, mako messages,
  custom-module labels): Spanish (the user is a Spanish speaker; this
  is a personal laptop).
- When the user writes to the agent in Spanish, reply in Spanish.

---

## 8. When to ask the user

Ask before doing if:

- The request is ambiguous or could be interpreted multiple ways
  (e.g. "configure the bar" — top, bottom, both?).
- The change touches more than one stage at once.
- The change conflicts with a hard rule in CONTEXT §9.
- The action is destructive or has wide blast radius.

Otherwise, just do the work and report what changed.
