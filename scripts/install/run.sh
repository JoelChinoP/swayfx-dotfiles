#!/usr/bin/env bash
# run.sh — Master installer entrypoint.
#
# Runs stage scripts under scripts/install/stages/ in order. Stops at
# the first non-zero exit. Resumable with --from. Stage 99-* is excluded
# from the default run and only executes via --only / explicit --from.
#
# Verified against: .claude/PLAN.md §1
# Reviewed: 2026-05-10

set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGES_DIR="$ROOT/scripts/install/stages"
# shellcheck disable=SC1091
source "$ROOT/scripts/install/lib/common.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]...

  --all          Run every default stage in order (excludes optional 99-*).
  --from NN      Start at stage NN (e.g. --from 04).
  --only NN      Run only stage NN (e.g. --only 03).
  --list         Print stages and exit.
  --dry-run      Print actions, do not execute.
  --yes, -y      Skip confirmation prompt.
  -h, --help     Show this help.

If no flag is given, behaves like --all (with prompt).
EOF
}

# ── Flag parsing ──────────────────────────────────────────────────────
ALL=0; FROM=""; ONLY=""; LIST=0
DRY_RUN="${DRY_RUN:-0}"
YES="${YES:-0}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)        ALL=1; shift ;;
        --from)       FROM="${2:-}"; [[ -z "$FROM" ]] && { log_fatal "--from needs NN"; exit 2; }; shift 2 ;;
        --only)       ONLY="${2:-}"; [[ -z "$ONLY" ]] && { log_fatal "--only needs NN"; exit 2; }; shift 2 ;;
        --list)       LIST=1; shift ;;
        --dry-run)    DRY_RUN=1; shift ;;
        --yes|-y)     YES=1; shift ;;
        -h|--help)    usage; exit 0 ;;
        *)            log_fatal "unknown flag: $1"; usage; exit 2 ;;
    esac
done
export DRY_RUN YES STATE_DIR BACKUP_DIR LOG_FILE

# ── Discover stages ───────────────────────────────────────────────────
[[ -d "$STAGES_DIR" ]] || { log_fatal "stages dir missing: $STAGES_DIR"; exit 1; }

mapfile -t ALL_STAGES < <(find "$STAGES_DIR" -maxdepth 1 -type f -name '[0-9]*-*.sh' -printf '%f\n' | sort)
if (( ${#ALL_STAGES[@]} == 0 )); then
    log_fatal "no stages found in $STAGES_DIR"
    exit 1
fi

# ── --list ────────────────────────────────────────────────────────────
if (( LIST )); then
    echo "Stages available in $STAGES_DIR:"
    for s in "${ALL_STAGES[@]}"; do
        num="${s%%-*}"
        if [[ "$num" == 99 ]]; then
            printf '  %s   %s(optional — run with --only %s)%s\n' \
                "$s" "$C_DIM" "$num" "$C_RESET"
        else
            printf '  %s\n' "$s"
        fi
    done
    exit 0
fi

# ── Build run list ────────────────────────────────────────────────────
to_run=()
for s in "${ALL_STAGES[@]}"; do
    num="${s%%-*}"

    if [[ -n "$ONLY" ]]; then
        [[ "$num" == "$ONLY" ]] && to_run+=("$s")
        continue
    fi

    if [[ -n "$FROM" ]]; then
        [[ "$num" < "$FROM" ]] && continue
    fi

    # By default exclude optional stages (99-*) unless explicitly
    # selected via --only or --from.
    if [[ "$num" == 99 ]]; then
        [[ -n "$FROM" && "$FROM" == "99" ]] || continue
    fi

    to_run+=("$s")
done

if (( ${#to_run[@]} == 0 )); then
    log_fatal "nothing to run for the given flags"
    exit 1
fi

# ── Plan + confirm ────────────────────────────────────────────────────
echo "Stages to run:"
printf '  %s\n' "${to_run[@]}"
echo "Log file:  $LOG_FILE"
echo "State dir: $STATE_DIR"
(( DRY_RUN )) && echo "(dry-run mode — no changes will be applied)"
echo

if ! confirm "Proceed?"; then
    log_warn "aborted by user"
    exit 130
fi

# ── Execute ───────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"

for s in "${to_run[@]}"; do
    num="${s%%-*}"
    log_info "▶ Stage $s"

    if DRY_RUN="$DRY_RUN" YES="$YES" bash "$STAGES_DIR/$s"; then
        log_ok "✓ Stage $s"
        stage_mark_done "$num"
    else
        rc=$?
        log_fatal "✗ Stage $s failed (exit $rc) — aborting"
        echo
        echo "Fix the issue and resume with:"
        echo "  $0 --from $num"
        exit 1
    fi
done

log_ok "All requested stages completed."
echo
echo "Log:   $LOG_FILE"
echo "State: $STATE_DIR"
