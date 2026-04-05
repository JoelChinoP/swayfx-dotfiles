#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$HOME/.local/share/swayfx-dotfile-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { printf "${CYAN}[info]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[ok]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[warn]${NC} %s\n" "$*"; }

PACMAN_PACKAGES=(
  foot
  zellij
  waybar
  swaybg
  swayidle
  fuzzel
  mako
  thunar
  gvfs
  tumbler
  pipewire
  pipewire-pulse
  wireplumber
  pavucontrol
  networkmanager
  nm-connection-editor
  brightnessctl
  grim
  slurp
  wl-clipboard
  libnotify
  polkit
  polkit-gnome
  xdg-user-dirs
  xdg-utils
  xdg-desktop-portal-wlr
  xdg-desktop-portal-gtk
  qt5-wayland
  qt6-wayland
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  papirus-icon-theme
  adw-gtk3
)

AUR_PACKAGES=(
  swayfx
  nwg-dock
  bibata-cursor-theme
)

backup_path() {
  local target="$1"
  local relative="${target#$HOME/}"
  local backup_target="$BACKUP_DIR/$relative"

  [ -e "$target" ] || [ -L "$target" ] || return 0

  mkdir -p "$(dirname "$backup_target")"
  cp -a "$target" "$backup_target"
}

copy_file() {
  local src="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"
  backup_path "$dest"
  cp -a "$src" "$dest"
}

copy_dir_contents() {
  local src="$1"
  local dest="$2"

  mkdir -p "$dest"
  backup_path "$dest"
  cp -a "$src/." "$dest/"
}

remove_managed_file() {
  local target="$1"

  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_path "$target"
    rm -f "$target"
  fi
}

printf "\n${CYAN}SwayFX dotfiles${NC}\n\n"

if ! command -v pacman >/dev/null 2>&1; then
  warn "Este instalador es para Arch Linux o derivadas con pacman y AUR."
  warn "Si sigues en Pop!_OS, usa este repo como referencia y adapta los paquetes."
  exit 1
fi

info "Actualizando sistema"
sudo pacman -Syu

info "Instalando dependencias base para AUR"
sudo pacman -S --needed base-devel git

info "Instalando zsh y starship primero"
sudo pacman -S --needed zsh starship

if [ "${SHELL:-}" != "$(command -v zsh)" ]; then
  info "Cambiando el shell por defecto a zsh"
  chsh -s "$(command -v zsh)"
fi

if ! command -v paru >/dev/null 2>&1; then
  info "Instalando paru"
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  (
    cd "$tmpdir/paru"
    makepkg -si
  )
fi

info "Instalando paquetes principales"
sudo pacman -S --needed "${PACMAN_PACKAGES[@]}"

info "Instalando paquetes AUR"
paru -S --needed "${AUR_PACKAGES[@]}"
if ! paru -S --needed swaylock-effects; then
  warn "No se encontró swaylock-effects estable; intentando swaylock-effects-git"
  paru -S --needed swaylock-effects-git
fi

mkdir -p "$BACKUP_ROOT"
info "Respaldando configuraciones existentes en $BACKUP_DIR"

copy_file "$DOTFILES/.zshrc" "$HOME/.zshrc"
copy_file "$DOTFILES/.zprofile" "$HOME/.zprofile"
copy_file "$DOTFILES/starship.toml" "$HOME/.config/starship.toml"

copy_dir_contents "$DOTFILES/.config/sway" "$HOME/.config/sway"
copy_dir_contents "$DOTFILES/.config/waybar" "$HOME/.config/waybar"
copy_dir_contents "$DOTFILES/.config/foot" "$HOME/.config/foot"
copy_dir_contents "$DOTFILES/.config/fuzzel" "$HOME/.config/fuzzel"
copy_dir_contents "$DOTFILES/.config/zellij" "$HOME/.config/zellij"
copy_dir_contents "$DOTFILES/.config/mako" "$HOME/.config/mako"
copy_dir_contents "$DOTFILES/.config/nwg-dock" "$HOME/.config/nwg-dock"
copy_dir_contents "$DOTFILES/.config/swayidle" "$HOME/.config/swayidle"
copy_dir_contents "$DOTFILES/.config/environment.d" "$HOME/.config/environment.d"
copy_dir_contents "$DOTFILES/.config/gtk-3.0" "$HOME/.config/gtk-3.0"
copy_dir_contents "$DOTFILES/.config/gtk-4.0" "$HOME/.config/gtk-4.0"

remove_managed_file "$HOME/.config/swaylock/config"
remove_managed_file "$HOME/.config/nwg-dock/dock.json"

chmod +x "$HOME/.config/sway/scripts/"*.sh
chmod +x "$HOME/.config/waybar/scripts/"*.sh

xdg-user-dirs-update
sudo systemctl enable --now NetworkManager.service

success "Dotfiles instalados"
printf "\n1. Cierra sesión.\n2. Entra por TTY1.\n3. SwayFX arrancará desde ~/.zprofile.\n4. Coloca tu fondo en ~/.config/sway/wallpaper.jpg si quieres usar imagen.\n\n"
