# ✦ SwayFX Dotfiles — Caelestia-inspired

> Configuración minimalista para **SwayFX** sobre Pop!\_OS / Arch Linux.
> Optimizada para **Ryzen 5 7430U** con gráficos integrados AMD y 12 GB RAM.

---

## 🖼️ Estilo visual

| Elemento | Valor |
|---|---|
| Paleta | Catppuccin Mocha |
| Acento focal | Amarillo `#f9e2af` (herencia de Pop!\_OS) |
| Bordes redondeados | 10 px (SwayFX `corner_radius`) |
| Blur | Solo terminal (`foot`) y gestor de archivos (`thunar`) al 85 % de opacidad |
| Sombras | Activadas, radio 20 px |
| Dim inactivo | 7 % |
| Fuente | JetBrainsMono Nerd Font 10–13 |

---

## 📁 Estructura

```
dotfiles/
├── install.sh                     ← Script de instalación completo
├── starship.toml                  → ~/.config/starship.toml
├── .zshrc                         → ~/
├── .zprofile                      → ~/  (auto-inicio de SwayFX en TTY1)
└── .config/
    ├── sway/
    │   ├── config                 ← Configuración principal de SwayFX
    │   └── wallpaper.jpg          ← Tu wallpaper (añadir manualmente)
    ├── waybar/
    │   ├── config.jsonc           ← Módulos de la barra superior
    │   ├── style.css              ← Estilo visual
    │   └── scripts/
    │       ├── notifications.sh   ← Ícono de mako
    │       └── power-menu.sh      ← Menú de apagado con fuzzel
    ├── foot/
    │   └── foot.ini               ← Terminal con transparencia 85 %
    ├── zellij/
    │   └── config.kdl             ← Multiplexor de terminal
    ├── fuzzel/
    │   └── fuzzel.ini             ← Lanzador de aplicaciones
    ├── swaylock/
    │   └── config                 ← Pantalla de bloqueo con blur
    ├── swayidle/
    │   └── config                 ← Apagado de pantalla e inactividad
    ├── mako/
    │   └── config                 ← Notificaciones
    ├── nwg-dock/
    │   ├── style.css              ← Estilo del dock inferior
    │   └── dock.json              ← Apps ancladas (editar a gusto)
    ├── gtk-3.0/settings.ini       ← Tema GTK oscuro
    ├── gtk-4.0/settings.ini
    └── environment.d/
        └── wayland.conf           ← Variables de entorno persistentes
```

---

## ⚡ Instalación rápida

```bash
# Clonar el repositorio
git clone https://github.com/TU_USUARIO/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Dar permisos y ejecutar
chmod +x install.sh
./install.sh
```

El script instala todo automáticamente. Al terminar, **cierra sesión y vuelve a iniciar en TTY1** — SwayFX arrancará solo.

---

## 🔧 Instalación manual (paso a paso)

### 1. Actualizar el sistema
```bash
sudo pacman -Syu
```

### 2. Dependencias base para compilar AUR
```bash
sudo pacman -S --needed base-devel git
```

### 3. Instalar zsh y starship primero
```bash
sudo pacman -S zsh starship
chsh -s $(which zsh)
```

### 4. Instalar paru (helper AUR)
```bash
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

### 5. Instalar SwayFX desde AUR
```bash
paru -S swayfx
```

### 6. Instalar las herramientas
```bash
sudo pacman -S foot zellij waybar swaybg swayidle \
  fuzzel mako thunar gvfs \
  pipewire pipewire-pulse wireplumber pavucontrol \
  nm-connection-editor brightnessctl \
  grim slurp wl-clipboard \
  polkit-gnome adw-gtk3 \
  ttf-jetbrains-mono-nerd papirus-icon-theme \
  xdg-user-dirs vulkan-radeon libva-mesa-driver

paru -S swaylock-effects nwg-dock bibata-cursor-theme
```

### 7. Configurar inicio automático de SwayFX
Añade esto al final de `~/.zprofile`:
```bash
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    exec sway
fi
```

---

## ⌨️ Atajos de teclado

| Atajo | Acción |
|---|---|
| `Super + Return` | Abrir terminal (foot + zellij) |
| `Super + D` | Lanzador de apps (fuzzel) |
| `Super + Shift + E` | Gestor de archivos (thunar) |
| `Super + Q` | Cerrar ventana |
| `Super + F` | Pantalla completa |
| `Super + M` | Minimizar ventana (al scratchpad) |
| `Super + Shift + M` | Restaurar ventana minimizada |
| `Super + Ctrl + L` | Bloquear pantalla |
| `Super + Ctrl + R` | Recargar configuración de Sway |
| `Super + H/J/K/L` | Mover foco (hjkl / flechas) |
| `Super + Shift + H/J/K/L` | Mover ventana |
| `Super + Shift + F` | Toggle ventana flotante |
| `Super + R` | Modo redimensionar |
| `Super + 1–6` | Cambiar workspace |
| `Super + Shift + 1–6` | Mover ventana al workspace |
| `Print` | Captura de pantalla completa |
| `Super + Print` | Captura de región (slurp) |
| `XF86AudioRaiseVolume` | Subir volumen 5 % |
| `XF86MonBrightnessUp` | Subir brillo 5 % |

---

## 🎨 Personalización

### Cambiar wallpaper
```bash
cp tu-imagen.jpg ~/.config/sway/wallpaper.jpg
swaymsg reload
```

### Añadir apps al dock inferior
Edita `~/.config/nwg-dock/dock.json` con el formato:
```json
[{"exec": "nombre-binario", "icon": "nombre-icono"}]
```

### Ajustar opacidad del blur
En `~/.config/sway/config`, modifica:
```
for_window [app_id="foot"]   blur enable, opacity 0.85
```
Cambia `0.85` a cualquier valor entre `0.0` y `1.0`.

### Cambiar layout de teclado
En `~/.config/sway/config`:
```
input type:keyboard {
    xkb_layout  latam   # Cambia por: us, es, etc.
}
```

### Timeout de pantalla
Edita `~/.config/swayidle/config` y ajusta los valores en segundos.

---

## 🔋 Optimizaciones para iGPU AMD

Las siguientes variables en `.config/environment.d/wayland.conf` están ajustadas para el **Ryzen 5 7430U** con gráficos integrados RDNA 2:

```bash
WLR_RENDERER=vulkan       # Vulkan > OpenGL en wlroots moderno
AMD_VULKAN_ICD=RADV       # Driver Vulkan de Mesa (mejor rendimiento)
LIBVA_DRIVER_NAME=radeonsi # Aceleración de video VA-API
VDPAU_DRIVER=radeonsi      # Aceleración VDPAU
```

El blur está restringido **solo a foot y thunar** para minimizar el uso de GPU con solo 500 MB de VRAM disponible.

---

## 📦 Lista completa de paquetes

| Herramienta | Paquete |
|---|---|
| Compositor | `swayfx` (AUR) |
| Shell | `zsh` |
| Prompt | `starship` |
| Terminal | `foot` |
| Multiplexor | `zellij` |
| Barra superior | `waybar` |
| Dock inferior | `nwg-dock` (AUR) |
| Lanzador | `fuzzel` |
| Bloqueo | `swaylock-effects` (AUR) |
| Inactividad | `swayidle` |
| Fondo de pantalla | `swaybg` |
| Notificaciones | `mako` |
| Archivos | `thunar` + `gvfs` + `tumbler` |
| Audio | `pipewire` + `pipewire-pulse` + `wireplumber` |
| Red (GUI) | `nm-connection-editor` |
| Fuente | `ttf-jetbrains-mono-nerd` |
| Íconos | `papirus-icon-theme` |
| Cursor | `bibata-cursor-theme` (AUR) |
| GTK Dark | `adw-gtk3` |
| Drivers AMD | `vulkan-radeon` + `libva-mesa-driver` |
| Capturas | `grim` + `slurp` |
| Brillo | `brightnessctl` |
| Portapapeles | `wl-clipboard` |

---

## 🐛 Solución de problemas

**SwayFX no inicia:**
```bash
# Verificar que está instalado
which sway
# Revisar log de inicio
sway > /tmp/sway.log 2>&1
cat /tmp/sway.log
```

**Waybar no muestra íconos:**
```bash
# Verificar que la fuente Nerd Font está instalada
fc-list | grep "JetBrainsMono"
```

**Blur no funciona:**  
SwayFX requiere que la ventana tenga `opacity < 1.0`. Verifica que foot tiene `alpha = 0.85` en `foot.ini`.

**nwg-dock no aparece:**  
Asegúrate de que `scratchpad_minimize enable` está en la config de SwayFX.

---

*Inspirado en [Caelestia](https://github.com/caelestia-dots/caelestia) para Hyprland.*
