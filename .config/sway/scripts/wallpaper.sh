#!/usr/bin/env bash
set -euo pipefail

wallpaper="$HOME/.config/sway/wallpaper.jpg"

if [ -f "$wallpaper" ]; then
  exec swaybg -i "$wallpaper" -m fill
fi

exec swaybg -c 000000
