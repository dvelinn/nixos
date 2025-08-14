#!/usr/bin/env bash
set -euo pipefail
SRC="$HOME/.mydotfiles/com.ml4w.dotfiles.stable"
HOME_DIR="$HOME"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$CFG_DIR"

# Top-level dotfiles into $HOME
for f in .bashrc .gtkrc-2.0 .Xresources .zshrc; do
  [ -e "$SRC/$f" ] && ln -sfn "$SRC/$f" "$HOME_DIR/$f"
done

# Everything under .config/ into $XDG_CONFIG_HOME
if [ -d "$SRC/.config" ]; then
  shopt -s nullglob dotglob
  for item in "$SRC/.config"/*; do
    name="$(basename "$item")"
    ln -sfn "$item" "$CFG_DIR/$name"
  done
fi

echo "ML4W dotfiles applied for $HOME_DIR"
