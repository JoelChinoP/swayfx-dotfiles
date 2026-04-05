#!/usr/bin/env bash
# Menú de energía con fuzzel
# Opciones: Apagar · Reiniciar · Suspender · Cerrar sesión · Cancelar

declare -A opciones=(
  ["󰐥  Apagar"]="systemctl poweroff"
  ["󰑓  Reiniciar"]="systemctl reboot"
  ["󰒲  Suspender"]="systemctl suspend"
  ["󰍃  Cerrar sesión"]="swaymsg exit"
)

orden=(
  "󰐥  Apagar"
  "󰑓  Reiniciar"
  "󰒲  Suspender"
  "󰍃  Cerrar sesión"
)

seleccion=$(printf '%s\n' "${orden[@]}" | fuzzel --dmenu \
  --prompt "  " \
  --width 22 \
  --lines 4 \
  --font "JetBrainsMono Nerd Font:size=13" \
  --background-color=1e1e2edd \
  --text-color=cdd6f4ff \
  --match-color=f9e2afff \
  --selection-color=313244ff \
  --selection-text-color=f9e2afff \
  --border-color=f9e2af44 \
  --border-width=1 \
  --border-radius=10)

[[ -n "$seleccion" ]] && eval "${opciones[$seleccion]}"
