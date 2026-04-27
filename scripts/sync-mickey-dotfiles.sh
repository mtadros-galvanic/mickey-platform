#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_REPO="${1:-$ROOT_DIR/../mickey-dotfiles}"
DEST_DIR="$ROOT_DIR/ansible/files/dotfiles"

required_paths=(
  "$SOURCE_REPO/dot_zshrc.tmpl"
  "$SOURCE_REPO/dot_tmux.conf.tmpl"
  "$SOURCE_REPO/dot_gitconfig"
  "$SOURCE_REPO/dot_config/starship.toml"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "missing required dotfiles source: $path" >&2
    exit 1
  fi
done

install -d "$DEST_DIR"
install -m 0644 "$SOURCE_REPO/dot_zshrc.tmpl" "$DEST_DIR/.zshrc"
install -m 0644 "$SOURCE_REPO/dot_tmux.conf.tmpl" "$DEST_DIR/.tmux.conf"
install -m 0644 "$SOURCE_REPO/dot_gitconfig" "$DEST_DIR/.gitconfig"
install -m 0644 "$SOURCE_REPO/dot_config/starship.toml" "$DEST_DIR/starship.toml"

printf '%s\n' "synced curated dotfiles from $SOURCE_REPO into $DEST_DIR"
