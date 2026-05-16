# ~/.zshrc — read by interactive zsh shells.
#
# Verified against: ArchWiki "zsh", zshoptions(1)
# Reviewed: 2026-05-16

# ── History ───────────────────────────────────────────────────────────
HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
mkdir -p "$(dirname "$HISTFILE")"

setopt INC_APPEND_HISTORY        # write each command immediately
setopt SHARE_HISTORY             # all shells share one history
setopt HIST_IGNORE_DUPS          # do not store duplicates of the previous cmd
setopt HIST_IGNORE_SPACE         # ignore commands starting with a space
setopt HIST_REDUCE_BLANKS        # collapse runs of whitespace before saving
setopt EXTENDED_HISTORY          # save timestamp + duration

# ── Behaviour ─────────────────────────────────────────────────────────
setopt AUTO_CD                   # `dirname` alone cd's into it
setopt AUTO_PUSHD                # cd pushes to dir stack
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS      # allow # comments in interactive shells

# ── Completion ────────────────────────────────────────────────────────
autoload -U colors && colors
autoload -Uz compinit
zmodload zsh/complist
mkdir -p "$XDG_CACHE_HOME/zsh"
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"

# Case-insensitive completion, group results by tag.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''

# ── Key bindings (sane defaults) ──────────────────────────────────────
bindkey -e                                   # emacs keymap
bindkey '^[[H'   beginning-of-line           # Home
bindkey '^[[F'   end-of-line                 # End
bindkey '^[[3~'  delete-char                 # Delete
bindkey '^[[1;5C' forward-word               # Ctrl+Right
bindkey '^[[1;5D' backward-word              # Ctrl+Left

# History prefix search, like Oh My Zsh: type `cd ` and press Up to
# cycle only through previous commands that begin with that prefix.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zmodload zsh/terminfo 2>/dev/null || true
bindkey "${terminfo[kcuu1]:-$'\e[A'}" up-line-or-beginning-search
bindkey "${terminfo[kcud1]:-$'\e[B'}" down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^P' up-line-or-beginning-search
bindkey '^N' down-line-or-beginning-search

# ── Plugins (installed via pacman) ────────────────────────────────────
[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] \
    && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] \
    && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Subtle autosuggest color on near-black background.
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#5a5a66"

# Disable path highlighting, which is too noisy on the prompt and in the
ZSH_HIGHLIGHT_STYLES[path]=none
ZSH_HIGHLIGHT_STYLES[path_prefix]=none

# ── LS_COLORS ────────────────────────────────────────────────────────
# Los defaults de dircolors usan fondos brillantes (ow=34;42, tw=30;42)
# que en fondo negro pierden el texto. Se reemplazan por solo foreground.
#   ow = other-writable (sin sticky)  → azul negrita
#   tw = sticky + world-writable      → cian negrita
#   st = sticky (no world-writable)   → azul subrayado
eval "$(dircolors -b 2>/dev/null)" || true
export LS_COLORS="${LS_COLORS}:ow=1;34:tw=1;36:st=4;34"

# ── Functions ─────────────────────────────────────────────────────────
vscode() {
    code . --profile "${1:?usage: vscode <profile>}"
}

# ── Aliases ───────────────────────────────────────────────────────────
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# Pacman/paru shortcuts.
alias p='sudo pacman'
alias pi='sudo pacman -S --needed'
alias pr='sudo pacman -Rns'
alias pq='pacman -Q'
alias ps='pacman -Ss'
alias y='paru'

# Quick reload.
alias zreload='exec zsh -l'

# ── Prompt: starship ──────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# Keep Starship's add_newline=false, but separate command output from
# the next prompt after the command has finished (except clear/reset).
autoload -Uz add-zsh-hook
_swayfx_last_cmd=""
_swayfx_capture_last_command() {
    local cmd="${1#"${1%%[![:space:]]*}"}"
    _swayfx_last_cmd="$cmd"
}
_swayfx_prompt_spacing_after_command() {
    if [[ -n "${_SWAYFX_PROMPT_SPACING_READY:-}" ]]; then
        case "$_swayfx_last_cmd" in
            (clear|clear\ *|reset|reset\ *|tput\ clear*|tput\ reset*)
                ;;
            (*)
                print
                ;;
        esac
    fi
    _SWAYFX_PROMPT_SPACING_READY=1
}
add-zsh-hook preexec _swayfx_capture_last_command
add-zsh-hook precmd _swayfx_prompt_spacing_after_command
