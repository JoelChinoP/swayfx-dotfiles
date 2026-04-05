#!/usr/bin/env bash
set -euo pipefail

selection=$(printf '%s\n' \
  "󰍃  Bloquear" \
  "󰒲  Suspender" \
  "󰑓  Reiniciar" \
  "󰐥  Apagar" | fuzzel --dmenu \
  --prompt "power> " \
  --width 24 \
  --lines 4 \
  --font "JetBrainsMono Nerd Font:size=13" \
  --background-color=11111bee \
  --text-color=cdd6f4ff \
  --match-color=f3e2a7ff \
  --selection-color=181825ff \
  --selection-text-color=f3e2a7ff \
  --border-color=f3e2a744 \
  --border-width=1 \
  --border-radius=10)

case "${selection:-}" in
  "󰍃  Bloquear")
    exec "$HOME/.config/sway/scripts/lock.sh"
    ;;
  "󰒲  Suspender")
    exec systemctl suspend
    ;;
  "󰑓  Reiniciar")
    exec systemctl reboot
    ;;
  "󰐥  Apagar")
    exec systemctl poweroff
    ;;
esac
