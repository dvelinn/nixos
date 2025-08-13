#!/usr/bin/env bash
set -euo pipefail

# Setup config
OUT_DIR="${HOME}"
DATE="$(date +%F)"
HOST="$(hostname)"
ARCHIVE_BASENAME="NixOS_Backup-${HOST}-${DATE}"
ARCHIVE="${OUT_DIR}/${ARCHIVE_BASENAME}.tar.gz"

msg(){ printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m!! \033[0m%s\n" "$*"; }

# Export Flatpaks list
msg "Exporting Flatpaks list to ~/.mydotfiles/scripts/flatpaks.csv"
if command -v flatpaks-export >/dev/null 2>&1; then
  flatpaks-export "${HOME}/.mydotfiles/scripts/flatpaks.csv" || warn "flatpaks-export failed (continuing)"
else
  warn "flatpaks-export not found; skipping Flatpak list export"
fi

# 2) Stream $HOME directly into a gzip tarball with ML4W excludes
msg "Creating archive: ${ARCHIVE}"
cd "${HOME}"

tar --xattrs --acls --one-file-system --numeric-owner \
  --exclude="./$(basename "${ARCHIVE}")" \
  --exclude './NixOS_Backup-*.tar.*' \
  --exclude 'Backup' \
  --exclude 'Mjolnir' \
  --exclude '.cache' \
  --exclude '.cargo' \
  --exclude '.mydotfiles' \
  --exclude '.nix-defexpr' \
  --exclude '.nix-profile' \
  --exclude '.rustup' \
  --exclude '.bashrc' \
  --exclude '.gtkrc-2.0' \
  --exclude '.Xresources' \
  --exclude '.zshrc' \
  --exclude '.config.bashrc' \
  --exclude '.config/fastfetch' \
  --exclude '.config/gtk-3.0' \
  --exclude '.config/gtk-4.0' \
  --exclude '.config/hypr' \
  --exclude '.config/kitty' \
  --exclude '.config/matugen' \
  --exclude '.config/ml4w' \
  --exclude '.config/nvim' \
  --exclude '.config/nwg-dock-hyprland' \
  --exclude '.config/ohmyposh' \
  --exclude '.config/qt6ct' \
  --exclude '.config/rofi' \
  --exclude '.config/swaync' \
  --exclude '.config/vim' \
  --exclude '.config/wallust' \
  --exclude '.config/waybar' \
  --exclude '.config/waypaper' \
  --exclude '.config/wlogout' \
  --exclude '.config/xsettingsd' \
  --exclude '.config/zshrc' \
  -cpzf "${ARCHIVE}" .

msg "Backup complete: ${ARCHIVE}"
