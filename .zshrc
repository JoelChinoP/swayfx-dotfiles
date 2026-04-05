# ════════════════════════════════════════════════
#  ~/.zshrc — ZSH + Starship + Zellij
# ════════════════════════════════════════════════

# ── Historial ─────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ── Opciones básicas ──────────────────────────────
setopt AUTO_CD
setopt CORRECT
setopt NO_BEEP

# ── Completado ────────────────────────────────────
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ── Path ──────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# ── Starship prompt ───────────────────────────────
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"

# ── Zellij — auto-start si no estamos ya dentro ───
# Solo dentro de una sesión interactiva Wayland
if [[ -n "$WAYLAND_DISPLAY" ]] && \
   [[ -z "$ZELLIJ" ]] && \
   [[ $- == *i* ]]; then
    exec zellij attach --create
fi

# ── Aliases útiles ────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ..='cd ..'
alias ...='cd ../..'

# SwayFX / Wayland
alias sway-reload='swaymsg reload'
alias waybar-reload='pkill waybar; waybar &'

# Pacman / paru
alias update='paru -Syu'
alias install='paru -S'
alias remove='sudo pacman -Rs'
alias orphans='sudo pacman -Rns $(pacman -Qtdq)'
