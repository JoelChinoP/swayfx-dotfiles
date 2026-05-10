# ~/.zshenv — read by every zsh invocation (login or not).
# Keep light: only env vars that all shells need.
#
# Verified against: zshall(1), XDG Base Directory spec
# Reviewed: 2026-05-10

# XDG base directories (only set if not already set by /etc/environment).
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
export XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME

# User-local binaries (powermenu, screenshot helpers, etc.).
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Tell starship where its config lives.
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"
