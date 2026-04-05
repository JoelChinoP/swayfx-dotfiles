# ════════════════════════════════════════════════
#  ~/.zprofile — Inicio automático de SwayFX
# ════════════════════════════════════════════════

# Variables de entorno Wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export GDK_BACKEND=wayland
export SDL_VIDEODRIVER=wayland
export CLUTTER_BACKEND=wayland
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=sway

# AMD iGPU: forzar renderizado acelerado (Ryzen 5 7430U)
export WLR_RENDERER=vulkan
export AMD_VULKAN_ICD=RADV
export LIBVA_DRIVER_NAME=radeonsi
export VDPAU_DRIVER=radeonsi

# Performance: usar pipeline del compositor nativo
export WLR_NO_HARDWARE_CURSORS=0

# Iniciar SwayFX automáticamente en TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec sway
fi
