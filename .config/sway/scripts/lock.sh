#!/usr/bin/env bash
set -euo pipefail

exec swaylock \
  --screenshots \
  --clock \
  --indicator \
  --indicator-radius 90 \
  --indicator-thickness 8 \
  --effect-scale 0.5 \
  --effect-blur 6x3 \
  --effect-scale 2 \
  --effect-vignette 0.35:0.75 \
  --fade-in 0.15 \
  --timestr "%H:%M" \
  --datestr "%a, %d %b" \
  --font "JetBrainsMono Nerd Font" \
  --ring-color f3e2a7dd \
  --key-hl-color f9e2afff \
  --line-color 00000000 \
  --inside-color 000000dd \
  --separator-color 00000000 \
  --text-color e8e8e8ff \
  --inside-ver-color 111111dd \
  --ring-ver-color 89b4fadd \
  --text-ver-color e8e8e8ff \
  --inside-wrong-color 111111dd \
  --ring-wrong-color f38ba8dd \
  --text-wrong-color f38ba8ff \
  --bs-hl-color f38ba8ff \
  --indicator-caps-lock \
  --ignore-empty-password \
  --show-failed-attempts
