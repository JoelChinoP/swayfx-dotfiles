# SwayFX Dotfiles

Dotfiles para un escritorio `SwayFX` minimalista, negro y ligero, inspirado en la limpieza visual de Caelestia pero adaptado a una laptop con `Ryzen 5 7430U`, iGPU AMD y foco fuerte en eficiencia.

La idea base de este repo es muy simple:

- barra superior con ventanas abiertas a la izquierda, reloj al centro y estado del sistema a la derecha;
- barra inferior solo para aplicaciones;
- blur solo en `foot` y `Thunar`;
- acento amarillo pastel para recordar el estilo de Pop!_OS;
- nada de efectos innecesarios sobre Waybar, dock o notificaciones.

## Importante

Tu contexto menciona `Pop!_OS`, pero los pasos que pediste usan `pacman`, `paru` y AUR. Eso corresponde a `Arch Linux` o derivadas, no a Pop!_OS.

Este repo deja:

- la estetica inspirada en lo que te gusta de Pop!_OS;
- la instalacion documentada para Arch/AUR, porque fue exactamente la base que pediste.

Si sigues en Pop!_OS, puedes reutilizar casi toda la carpeta de dotfiles, pero debes adaptar la instalacion de paquetes a `apt` y compilar `swayfx`/`swaylock-effects` por tu cuenta.

## Que resuelve este setup

### Layout

- `Waybar` arriba:
  - izquierda: ventanas abiertas con `wlr/taskbar`;
  - centro: reloj;
  - derecha: bateria, audio, red, notificaciones y energia.
- `nwg-dock` abajo:
  - sin launcher;
  - sin selector de workspaces;
  - solo dock de aplicaciones.

### Blur y transparencia

- `foot`: transparencia nativa al `85%` y blur desde `SwayFX`.
- `Thunar`: opacidad al `85%` y blur desde `SwayFX`.
- todo lo demas: sin blur.

### Ventanas y botones

SwayFX no replica por si solo los botones tipo GNOME/Pop!_OS en todas las ventanas en mosaico. Para conservar ese flujo de trabajo, este repo mezcla dos enfoques:

- `foot` usa `CSD` y muestra botones de minimizar, maximizar y cerrar;
- `Thunar` mantiene sus decoraciones GTK;
- `Waybar` permite operar ventanas desde la taskbar:
  - clic izquierdo: minimizar o restaurar;
  - clic derecho: maximizar;
  - clic medio: cerrar.

## Estructura

```text
.
├── install.sh
├── starship.toml
├── .zprofile
├── .zshrc
└── .config
    ├── environment.d
    │   └── wayland.conf
    ├── foot
    │   └── foot.ini
    ├── fuzzel
    │   └── fuzzel.ini
    ├── gtk-3.0
    │   ├── gtk.css
    │   └── settings.ini
    ├── gtk-4.0
    │   ├── gtk.css
    │   └── settings.ini
    ├── mako
    │   └── config
    ├── nwg-dock
    │   └── style.css
    ├── sway
    │   ├── config
    │   └── scripts
    │       ├── lock.sh
    │       └── wallpaper.sh
    ├── swayidle
    │   └── config
    ├── waybar
    │   ├── config.jsonc
    │   ├── style.css
    │   └── scripts
    │       ├── notifications.sh
    │       └── power-menu.sh
    └── zellij
        └── config.kdl
```

## Instalacion rapida

```bash
git clone https://github.com/TU_USUARIO/swayfx-dotfile.git ~/swayfx-dotfile
cd ~/swayfx-dotfile
chmod +x install.sh
./install.sh
```

El instalador:

- actualiza el sistema;
- instala primero `zsh` y `starship`;
- instala `paru` si no existe;
- instala `swayfx`, `swaylock-effects`, `waybar`, `foot`, `fuzzel`, `nwg-dock` y el resto de herramientas;
- hace backup de tus archivos existentes en `~/.local/share/swayfx-dotfile-backups/`;
- copia la configuracion a `~/.config` y a tu home.

## Instalacion manual detallada

### 1. Actualizar el sistema

```bash
sudo pacman -Syu
```

### 2. Instalar dependencias base para compilar desde AUR

```bash
sudo pacman -S --needed base-devel git
```

### 3. Instalar `zsh` y `starship` antes de todo

```bash
sudo pacman -S --needed zsh starship
chsh -s "$(which zsh)"
```

Ese orden es intencional para evitar que luego el terminal arranque con una shell distinta a la que esperan `foot`, `starship` y `zellij`.

### 4. Instalar `paru`

```bash
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

Confirma con `Y` cuando `pacman` o `makepkg` lo pidan.

### 5. Instalar SwayFX

```bash
paru -S swayfx
```

### 6. Instalar paquetes principales

```bash
sudo pacman -S --needed \
  foot zellij \
  waybar swaybg swayidle \
  fuzzel mako \
  thunar gvfs tumbler \
  pipewire pipewire-pulse wireplumber pavucontrol \
  networkmanager nm-connection-editor \
  brightnessctl grim slurp wl-clipboard libnotify \
  polkit polkit-gnome \
  xdg-user-dirs xdg-utils \
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
  qt5-wayland qt6-wayland \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
  papirus-icon-theme adw-gtk3
```

### 7. Instalar paquetes AUR

```bash
paru -S nwg-dock bibata-cursor-theme
paru -S swaylock-effects
```

Si en tu mirror o helper no aparece `swaylock-effects`, prueba:

```bash
paru -S swaylock-effects-git
```

### 8. Habilitar NetworkManager

```bash
sudo systemctl enable --now NetworkManager.service
```

### 9. Clonar este repo y copiar los dotfiles

```bash
git clone https://github.com/TU_USUARIO/swayfx-dotfile.git ~/swayfx-dotfile
cd ~/swayfx-dotfile
./install.sh
```

Si prefieres copiar a mano, mueve:

- `.zprofile` a `~/`
- `.zshrc` a `~/`
- `starship.toml` a `~/.config/`
- todo lo de `.config/` a `~/.config/`

### 10. Autoinicio de SwayFX en TTY1

Este repo ya deja el bloque dentro de `~/.zprofile`, pero si quieres verificarlo, debe quedar asi:

```bash
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "${XDG_VTNR:-0}" -eq 1 ]; then
  exec sway
fi
```

### 11. Primer inicio

1. Cierra sesion.
2. Entra por `TTY1`.
3. SwayFX arrancara automaticamente.
4. Si quieres fondo de pantalla, coloca una imagen en `~/.config/sway/wallpaper.jpg`.

Si no colocas imagen, el script de wallpaper deja fondo negro puro.

## Atajos importantes

| Atajo | Accion |
| --- | --- |
| `Super + Return` | Abrir `foot` |
| `Super + D` | Abrir `fuzzel` |
| `Super + Shift + E` | Abrir `Thunar` |
| `Super + Q` | Cerrar ventana |
| `Super + F` | Pantalla completa |
| `Super + Shift + F` | Ventana flotante |
| `Super + M` | Enviar a scratchpad |
| `Super + Shift + M` | Recuperar scratchpad |
| `Super + Ctrl + L` | Bloquear pantalla |
| `Super + Ctrl + R` | Recargar SwayFX |
| `Super + H/J/K/L` | Cambiar foco |
| `Super + Shift + H/J/K/L` | Mover ventana |
| `Super + R` | Modo resize |
| `Print` | Captura completa |
| `Super + Print` | Captura de region |

## Personalizacion rapida

### Cambiar wallpaper

```bash
cp TU_IMAGEN ~/.config/sway/wallpaper.jpg
swaymsg reload
```

### Cambiar layout del teclado

Edita `~/.config/sway/config`:

```text
input type:keyboard {
    xkb_layout latam
}
```

### Desactivar el comportamiento tipo minimizar

Si no te convence `scratchpad_minimize`, comenta esta linea en `~/.config/sway/config`:

```text
scratchpad_minimize enable
```

Lo dejo activado porque ayuda a que `Waybar` se comporte mas parecido a un escritorio tradicional, pero upstream lo considera una funcion todavia algo experimental.

### Quitar el negro forzado de GTK

Si alguna app GTK se ve rara, prueba mover temporalmente:

- `~/.config/gtk-3.0/gtk.css`
- `~/.config/gtk-4.0/gtk.css`

El tema base sigue siendo `adw-gtk3-dark`; esos `gtk.css` solo fuerzan una presencia mas negra.

## Decisiones tecnicas

- `foot` usa transparencia propia en vez de opacidad global para que el texto siga nítido.
- `Thunar` usa opacidad del compositor porque ahi si conviene el efecto completo.
- `Waybar` no lleva blur para respetar tu requisito y no gastar GPU innecesariamente.
- `nwg-dock` va sin launcher ni workspaces para que la barra inferior quede limpia.
- `swaylock-effects` usa `--effect-scale` antes y despues del blur para abaratar el coste del bloqueo.

## Documentacion verificada

Revisado el `2026-04-05` con documentacion upstream o manuales oficiales:

- SwayFX: https://github.com/WillPower3309/swayfx
- Waybar: https://man.archlinux.org/man/waybar.5
- Waybar `wlr/taskbar`: https://man.archlinux.org/man/waybar-wlr-taskbar.5.en
- Waybar `clock`: https://man.archlinux.org/man/waybar-clock.5.en
- Waybar `battery`: https://man.archlinux.org/man/waybar-battery.5.en
- Waybar `network`: https://man.archlinux.org/man/waybar-network.5.en
- Waybar `pulseaudio`: https://man.archlinux.org/man/waybar-pulseaudio.5.en
- foot: https://man.archlinux.org/man/foot.ini.5.en
- fuzzel: https://man.archlinux.org/man/fuzzel.1.en
- fuzzel config: https://man.archlinux.org/man/fuzzel.ini.5.en
- nwg-dock: https://github.com/nwg-piotr/nwg-dock
- swaylock-effects: https://github.com/mortie/swaylock-effects
- Zellij: https://zellij.dev/documentation/options
- Starship: https://starship.rs/config/

## Inspiracion visual

La inspiracion aqui no es copiar Caelestia tal cual, sino traducir su idea general a SwayFX:

- superficies limpias;
- negro dominante;
- acento suave;
- poco ruido visual;
- animacion y blur solo donde valen la pena.

Ese enfoque encaja mejor con SwayFX que intentar clonar uno a uno los detalles de un setup pensado para Hyprland.
