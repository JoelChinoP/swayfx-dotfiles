if [ -f "$HOME/.config/environment.d/wayland.conf" ]; then
  set -a
  . "$HOME/.config/environment.d/wayland.conf"
  set +a
fi

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
  exec sway
fi
