#!/usr/bin/env bash
# Muestra ícono de notificaciones para waybar
# Requiere: mako

if makoctl mode | grep -q "do-not-disturb"; then
  echo "󰂛"   # DND activo
else
  echo "󰂚"   # Normal
fi
