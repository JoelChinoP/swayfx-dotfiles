#!/usr/bin/env bash
# Stage 01 — Shell first.
#
# Installs zsh, starship, the QoL plugins, and the JetBrainsMono Nerd
# Font + Inter fonts. Sets zsh as the user's login shell. Stows the
# `zsh` and `starship` packages so the rest of the install runs in the
# configured shell.
#
# Verified against: .claude/PLAN.md §2 stage 01
# Reviewed: 2026-05-10

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/pkg.sh"

log_info "Stage 01 — shell (zsh + starship + plugins)"

# ── 1. Packages ───────────────────────────────────────────────────────
SHELL_PKGS=(
    zsh starship
    zsh-completions zsh-syntax-highlighting zsh-autosuggestions
    ttf-jetbrains-mono-nerd inter-font
)
pacman_install "${SHELL_PKGS[@]}"

# ── 2. Make zsh the login shell ───────────────────────────────────────
# `|| true` keeps `set -e` from aborting silently when zsh is missing
# (e.g. dry-run on a non-Arch box). The follow-up [[ -x ]] check then
# fatals with a useful message.
zsh_path="$(command -v zsh || true)"
if [[ -z "$zsh_path" || ! -x "$zsh_path" ]]; then
    if (( DRY_RUN )); then
        log_warn "zsh not on PATH (dry-run; would be installed by pacman)"
        zsh_path="/usr/bin/zsh"
    else
        log_fatal "zsh not on PATH after install"
        exit 1
    fi
fi

current_shell="$(getent passwd "$USER" | cut -d: -f7 || true)"
if [[ "$current_shell" == "$zsh_path" ]]; then
    log_ok "zsh already the login shell"
else
    log_info "changing login shell: ${current_shell:-<unknown>} → $zsh_path"
    run sudo chsh -s "$zsh_path" "$USER"
fi

# ── 3. Stow zsh + starship ────────────────────────────────────────────
# Single timestamp for any conflict backups in this stage.
export BACKUP_TS="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"

stow_package zsh
stow_package starship

# ── 4. Validation ─────────────────────────────────────────────────────
# In dry-run, no real changes were made — skip post-install validation.
if (( DRY_RUN )); then
    log_warn "skipping post-install validation (dry-run)"
    log_ok "Stage 01 dry-run complete"
    exit 0
fi

errs=0

if getent passwd "$USER" | grep -q "${zsh_path}\$"; then
    log_ok "login shell is zsh"
else
    log_error "login shell is not zsh (chsh may need a re-login)"
    (( errs++ ))
fi

if zsh -c 'starship --version' >/dev/null 2>&1; then
    log_ok "starship is callable from zsh"
else
    log_error "starship is not callable from zsh"
    (( errs++ ))
fi

for plugin_pkg in zsh-syntax-highlighting zsh-autosuggestions zsh-completions; do
    if pkg_installed "$plugin_pkg"; then
        log_ok "package present: $plugin_pkg"
    else
        log_error "package missing: $plugin_pkg"
        (( errs++ ))
    fi
done

if grep -q '^[[:space:]]*exec sway' "$HOME/.zprofile" 2>/dev/null; then
    log_ok "~/.zprofile contains the TTY1 exec-sway block"
else
    log_error "~/.zprofile missing 'exec sway' block"
    (( errs++ ))
fi

if [[ -L "$HOME/.config/starship.toml" ]]; then
    log_ok "starship.toml linked into ~/.config"
else
    log_error "~/.config/starship.toml is not a stow symlink"
    (( errs++ ))
fi

if (( errs > 0 )); then
    log_fatal "Stage 01 validation failed ($errs error(s))"
    exit 1
fi

log_ok "Stage 01 complete — log out and back in for the new shell to take effect"
log_warn "TTY1 will try 'exec sway' until stage 03 installs SwayFX; comment that line in ~/.zprofile if you need to log in to TTY1 in the meantime"
