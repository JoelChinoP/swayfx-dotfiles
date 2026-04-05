#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║    install.sh — SwayFX Dotfiles                          ║
# ║    Ryzen 5 7430U · Pop!_OS base · Caelestia-inspired     ║
# ╚══════════════════════════════════════════════════════════╝
set -e

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[·]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}  SwayFX Dotfiles · Instalación            ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# ── 0. Verificar que somos en Arch / Pop!_OS con pacman ──
if ! command -v pacman &>/dev/null; then
  warn "Este script está diseñado para Arch Linux o distribuciones basadas en él."
  warn "Adapta los comandos si usas otro gestor de paquetes."
fi

# ── 1. Actualizar sistema ────────────────────────────────
info "Actualizando sistema..."
sudo pacman -Syu --noconfirm

# ── 2. Dependencias base ─────────────────────────────────
info "Instalando dependencias base..."
sudo pacman -S --needed --noconfirm \
  base-devel git curl \
  zsh starship \
  foot zellij \
  waybar swaybg swaylock \
  fuzzel mako \
  thunar gvfs tumbler \
  pipewire pipewire-pulse wireplumber pavucontrol \
  network-manager-applet nm-connection-editor \
  brightnessctl \
  grim slurp \
  polkit-gnome \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji \
  papirus-icon-theme \
  xdg-user-dirs xdg-utils \
  qt5-wayland qt6-wayland \
  vulkan-radeon libva-mesa-driver mesa \
  wl-clipboard \
  swayidle \
  adw-gtk3 \
  bibata-cursor-theme

# ── 3. Instalar paru (helper AUR) ────────────────────────
if ! command -v paru &>/dev/null; then
  info "Instalando paru (helper AUR)..."
  cd /tmp
  git clone https://aur.archlinux.org/paru.git
  cd paru
  makepkg -si --noconfirm
  cd "$DOTFILES"
  success "paru instalado"
else
  success "paru ya está instalado"
fi

# ── 4. Instalar SwayFX desde AUR ─────────────────────────
info "Instalando SwayFX, nwg-dock, swaylock-effects y cursor desde AUR..."
paru -S --noconfirm swayfx nwg-dock swaylock-effects bibata-cursor-theme

# ── 5. ZSH como shell por defecto ────────────────────────
if [ "$SHELL" != "$(which zsh)" ]; then
  info "Cambiando shell por defecto a zsh..."
  chsh -s "$(which zsh)"
  success "Shell cambiado a zsh (efectivo en próximo login)"
fi

# ── 6. Crear directorios necesarios ──────────────────────
info "Creando directorios..."
mkdir -p \
  ~/.config/sway \
  ~/.config/waybar/scripts \
  ~/.config/foot \
  ~/.config/zellij \
  ~/.config/fuzzel \
  ~/.config/swaylock \
  ~/.config/mako \
  ~/.config/nwg-dock \
  ~/Pictures \
  ~/Wallpapers

# ── 7. Copiar dotfiles ───────────────────────────────────
info "Copiando configuraciones..."

cp -v "$DOTFILES/.zshrc"            ~/
cp -v "$DOTFILES/.zprofile"         ~/
cp -v "$DOTFILES/starship.toml"     ~/.config/

cp -rv "$DOTFILES/.config/sway/"        ~/.config/
cp -rv "$DOTFILES/.config/waybar/"      ~/.config/
cp -rv "$DOTFILES/.config/foot/"        ~/.config/
cp -rv "$DOTFILES/.config/zellij/"      ~/.config/
cp -rv "$DOTFILES/.config/fuzzel/"      ~/.config/
cp -rv "$DOTFILES/.config/swaylock/"    ~/.config/
cp -rv "$DOTFILES/.config/mako/"        ~/.config/
cp -rv "$DOTFILES/.config/nwg-dock/"        ~/.config/
cp -rv "$DOTFILES/.config/swayidle/"        ~/.config/
cp -rv "$DOTFILES/.config/gtk-3.0/"         ~/.config/
cp -rv "$DOTFILES/.config/gtk-4.0/"         ~/.config/
cp -rv "$DOTFILES/.config/environment.d/"   ~/.config/

# ── 8. Hacer ejecutables los scripts de waybar ──────────
chmod +x ~/.config/waybar/scripts/*.sh
success "Scripts de waybar marcados como ejecutables"

# ── 9. Descargar wallpaper por defecto ───────────────────
if [ ! -f ~/.config/sway/wallpaper.jpg ]; then
  info "Descargando wallpaper de ejemplo..."
  # Wallpaper oscuro neutro como placeholder
  curl -sL "https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?w=2560&q=80" \
    -o ~/.config/sway/wallpaper.jpg 2>/dev/null \
    || warn "No se pudo descargar el wallpaper. Coloca manualmente ~/.config/sway/wallpaper.jpg"
fi

# ── 10. xdg-user-dirs ────────────────────────────────────
xdg-user-dirs-update

# ── 11. Habilitar servicios ──────────────────────────────
info "Habilitando servicios de usuario..."
systemctl --user enable --now pipewire.service 2>/dev/null || true
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
systemctl --user enable --now wireplumber.service 2>/dev/null || true

echo ""
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Instalación completada                 ${NC}"
echo -e "${GREEN}══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}Próximos pasos:${NC}"
echo "  1. Cierra sesión y vuelve a iniciar en TTY1"
echo "  2. SwayFX iniciará automáticamente"
echo "  3. Coloca tu wallpaper en: ~/.config/sway/wallpaper.jpg"
echo ""
echo -e "  ${YELLOW}Atajos esenciales:${NC}"
echo "  Super+Return   → Terminal (foot + zellij)"
echo "  Super+D        → Lanzador (fuzzel)"
echo "  Super+Shift+E  → Gestor de archivos (thunar)"
echo "  Super+Q        → Cerrar ventana"
echo "  Super+F        → Pantalla completa"
echo "  Super+M        → Minimizar (a scratchpad)"
echo "  Super+Shift+M  → Restaurar minimizada"
echo "  Super+Ctrl+L   → Bloquear pantalla"
echo "  Super+Ctrl+R   → Recargar configuración"
echo ""
