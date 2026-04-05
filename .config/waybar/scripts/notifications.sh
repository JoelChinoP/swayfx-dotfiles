#!/usr/bin/env bash
set -euo pipefail

if ! command -v makoctl >/dev/null 2>&1; then
  echo "󰂚"
  exit 0
fi

if makoctl mode 2>/dev/null | grep -Fxq "do-not-disturb"; then
  echo "󰂛"
else
  echo "󰂚"
fi
