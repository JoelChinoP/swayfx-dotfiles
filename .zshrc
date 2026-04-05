HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

setopt AUTO_CD
setopt NO_BEEP

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

export STARSHIP_CONFIG="$HOME/.config/starship.toml"
eval "$(starship init zsh)"

if [[ -n "$WAYLAND_DISPLAY" ]] && \
   [[ -z "$ZELLIJ" ]] && \
   [[ $- == *i* ]]; then
  exec zellij attach --create main
fi

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias ..='cd ..'
alias ...='cd ../..'

alias sway-reload='swaymsg reload'
alias waybar-reload='pkill -x waybar; waybar &'

alias update='paru -Syu'
alias install='paru -S'
alias remove='sudo pacman -Rs'
alias orphans='sudo pacman -Rns $(pacman -Qtdq)'
