#!/usr/bin/env bash
# Common helpers sourced by run.sh and every stage script.
# This file is sourced, not executed. Do not run it directly.
#
# Verified against: project conventions in .claude/CONTEXT.md §6.3
# Reviewed: 2026-05-11

# Required env (with defaults so a stage script can also be sourced
# standalone for debugging):
LOG_FILE="${LOG_FILE:-$HOME/swayfx-dotfiles-install.log}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/swayfx-dotfiles/stages}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.local/share/swayfx-dotfiles/backups}"
DRY_RUN="${DRY_RUN:-0}"
YES="${YES:-0}"

# Colors only when stdout is a TTY.
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_DIM=$'\033[2m'
    C_INFO=$'\033[36m'; C_OK=$'\033[32m'; C_WARN=$'\033[33m'
    C_ERR=$'\033[31m';  C_FATAL=$'\033[1;31m'
else
    C_RESET=""; C_DIM=""; C_INFO=""; C_OK=""; C_WARN=""; C_ERR=""; C_FATAL=""
fi

mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR" "$BACKUP_DIR" 2>/dev/null || true

_log() {
    # $1 = level color, $2 = level tag, $3.. = message
    local color="$1" tag="$2"; shift 2
    local ts; ts="$(date +%H:%M:%S)"
    local line plain_line
    line="$(printf '%s[%s]%s %s[%-5s]%s %s' \
        "$C_DIM" "$ts" "$C_RESET" \
        "$color" "$tag" "$C_RESET" \
        "$*")"
    plain_line="$(printf '[%s] [%-5s] %s' "$ts" "$tag" "$*")"
    printf '%s\n' "$line" >&2
    local log_dir
    log_dir="$(dirname "$LOG_FILE")"
    if [[ -w "$log_dir" ]] && { [[ ! -e "$LOG_FILE" ]] || [[ -w "$LOG_FILE" ]]; }; then
        printf '%s\n' "$plain_line" >> "$LOG_FILE" || true
    fi
}

log_info()  { _log "$C_INFO"  INFO  "$@"; }
log_ok()    { _log "$C_OK"    OK    "$@"; }
log_warn()  { _log "$C_WARN"  WARN  "$@"; }
log_error() { _log "$C_ERR"   ERROR "$@"; }
log_fatal() { _log "$C_FATAL" FATAL "$@"; }

# Run a command unless DRY_RUN is set.
run() {
    if (( DRY_RUN )); then
        local IFS=' '
        printf '%sDRY:%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
        return 0
    fi
    "$@"
}

# Fatal-exit if a command is missing. In dry-run mode it warns instead
# of failing, so the preview can show the rest of the intended flow.
require() {
    if command -v "$1" >/dev/null 2>&1; then return 0; fi
    if (( DRY_RUN )); then
        log_warn "missing in dry-run (would be installed): $1"
        return 0
    fi
    log_fatal "required command missing: $1"
    exit 1
}

# Yes/no prompt. Returns 0 on yes, 1 otherwise. Skipped when YES=1.
confirm() {
    local prompt="${1:-Continue?}"
    if (( YES )); then return 0; fi
    local ans
    read -r -p "$prompt [y/N] " ans
    [[ "$ans" =~ ^[yY]([eE][sS])?$ ]]
}

# True if a pacman package is installed (quiet).
pkg_installed() {
    pacman -Q "$1" &>/dev/null
}

# Assert all listed packages are installed; log_fatal listing missing
# ones and return 1 if any are missing.
require_pkgs() {
    local missing=()
    local p
    for p in "$@"; do
        pkg_installed "$p" || missing+=("$p")
    done
    if (( ${#missing[@]} > 0 )); then
        local IFS=' '
        log_fatal "missing packages: ${missing[*]}"
        return 1
    fi
    return 0
}

# Assert the user belongs to all listed groups; add them with sudo if
# missing. New group membership only takes effect on next login.
require_groups() {
    local missing=() g
    for g in "$@"; do
        id -Gn "$USER" | tr ' ' '\n' | grep -qx "$g" || missing+=("$g")
    done
    if (( ${#missing[@]} > 0 )); then
        local space_joined comma_joined
        space_joined="$(IFS=' '; echo "${missing[*]}")"
        comma_joined="$(IFS=,;  echo "${missing[*]}")"
        log_warn "user '$USER' not in: $space_joined — adding"
        run sudo usermod -aG "$comma_joined" "$USER"
        log_warn "group changes apply on next login"
    fi
}

# Mark a stage done. Argument: the NN prefix (e.g. "00").
stage_mark_done() {
    (( DRY_RUN )) && return 0
    mkdir -p "$STATE_DIR"
    : > "$STATE_DIR/$1.done"
}

# True if a stage is already marked done.
stage_is_done() {
    [[ -f "$STATE_DIR/$1.done" ]]
}

# Stow a package, backing up any pre-existing real files that would
# conflict. Idempotent — if a target is already a symlink into this
# package, it is left alone.
#
# Usage: stow_package <package-name>
# Requires: $ROOT (repo root). Honors $DRY_RUN.
stow_package() {
    local pkg="$1"
    [[ -n "${ROOT:-}" ]] || { log_fatal "stow_package: \$ROOT not set"; return 1; }
    local pkg_dir="$ROOT/$pkg"

    if [[ ! -d "$pkg_dir" ]]; then
        log_warn "stow_package: package '$pkg' does not exist; skipping"
        return 0
    fi

    require stow

    local ts="${BACKUP_TS:-$(date +%Y%m%d-%H%M%S)}"
    local backup_target="$BACKUP_DIR/$ts/$pkg"
    local conflicts=0

    # Walk every file inside the package and back up any conflicting
    # real file in $HOME. Leave existing symlinks owned by this package
    # alone (idempotent re-stow).
    while IFS= read -r -d '' src_in_pkg; do
        local rel="${src_in_pkg#"$pkg_dir"/}"
        local home_path="$HOME/$rel"

        # The scripts package intentionally stows only ~/.local/bin.
        # scripts/install is repository tooling, not a user dotfile.
        case "$pkg/$rel" in
            scripts/install/*) continue ;;
        esac

        if [[ -L "$home_path" ]]; then
            local target
            target="$(readlink -f "$home_path" 2>/dev/null || true)"
            if [[ "$target" == "$src_in_pkg" ]]; then
                continue
            fi
            # Symlink to something else: treat as conflict, back up.
        elif [[ ! -e "$home_path" ]]; then
            continue
        fi

        (( ++conflicts ))
        run mkdir -p "$(dirname "$backup_target/$rel")"
        run mv "$home_path" "$backup_target/$rel"
    done < <(find "$pkg_dir" -type f -print0 2>/dev/null)

    if (( conflicts > 0 )); then
        log_warn "$pkg: $conflicts conflict(s) backed up to $backup_target"
    fi

    # Ensure shared parent dirs exist as real dirs before stowing.
    # Without this, the FIRST package whose source contains `.config/`
    # gets folded — stow turns ~/.config into a symlink to that one
    # package's .config/, and subsequent packages cannot stow into
    # ~/.config/ without conflicts.
    run mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share"

    log_info "stow -R $pkg"
    # --no-folding forces per-file symlinks (no directory symlinks).
    # This keeps the layout predictable across multiple packages that
    # share parent dirs like ~/.config/.
    run stow -R --no-folding --target "$HOME" -d "$ROOT" "$pkg"
}
