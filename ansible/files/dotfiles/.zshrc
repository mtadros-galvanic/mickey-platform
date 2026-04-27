# Curated zsh profile for the Mickey Ubuntu guests.

HISTFILE="$HOME/.zsh_history"
HISTSIZE=60000
SAVEHIST=50000

setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_DUPS

export LANG="en_US.UTF-8"

if [[ -d "$HOME/.local/bin" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

autoload -Uz compinit && compinit

if command -v nvim >/dev/null 2>&1; then
  export EDITOR="nvim"
  export VISUAL="nvim"
elif command -v vim >/dev/null 2>&1; then
  export EDITOR="vim"
  export VISUAL="vim"
fi

export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
