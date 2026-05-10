#!/usr/bin/env bash
# Common helpers sourced by run.sh and every stage script.
# This file is sourced, not executed. Do not run it directly.
#
# Verified against: project conventions in .claude/CONTEXT.md §6.3
# Reviewed: 2026-05-10

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
    printf '%s[%s]%s %s[%-5s]%s %s\n' \
        "$C_DIM" "$ts" "$C_RESET" \
        "$color" "$tag" "$C_RESET" \
        "$*" \
        | tee -a "$LOG_FILE" >&2
}

log_info()  { _log "$C_INFO"  INFO  "$@"; }
log_ok()    { _log "$C_OK"    OK    "$@"; }
log_warn()  { _log "$C_WARN"  WARN  "$@"; }
log_error() { _log "$C_ERR"   ERROR "$@"; }
log_fatal() { _log "$C_FATAL" FATAL "$@"; }

# Run a command unless DRY_RUN is set.
run() {
    if (( DRY_RUN )); then
        printf '%sDRY:%s %s\n' "$C_DIM" "$C_RESET" "$*" >&2
        return 0
    fi
    "$@"
}

# Fatal-exit if a command is missing.
require() {
    command -v "$1" >/dev/null 2>&1 \
        || { log_fatal "required command missing: $1"; exit 1; }
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
        log_warn "user '$USER' not in: ${missing[*]} — adding"
        local joined
        joined="$(IFS=,; echo "${missing[*]}")"
        run sudo usermod -aG "$joined" "$USER"
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
