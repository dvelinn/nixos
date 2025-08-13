#!/usr/bin/env bash
set -euo pipefail

# Keep flatpak from whining later on
export PATH="$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"

# Set paths
REPO="https://github.com/dvelinn/nixos.git"
DOTS="$HOME/.mydotfiles"
NIX_CFG="/etc/nixos/hardware-configuration.nix"
FLATPAKS="$DOTS/scripts/flatpaks.csv"

# Messages
msg(){ printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m!! \033[0m%s\n" "$*"; }
fail(){ printf "\033[1;31mXX \033[0m%s\n" "$*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    msg "Installing missing tool: $1"
    sudo nix-shell -p "nixpkgs.$1" >/dev/null 2>&1 || warn "Could not install $1 via nix-shell (continuing)"
  }
}

# Unpack tarball into $HOME
restore_home() {
  local BACKUP="${1:-}"
  [ -z "$BACKUP" ] && return 0
  [ -f "$BACKUP" ] || fail "Tarball not found: $BACKUP"
  msg "Restoring home from tarball: $BACKUP"
  tar -xpzf "$BACKUP" \
  --xattrs \
  --acls \
  --numeric-owner \
  -C "$HOME"
}

# Clone/update repo to ~/.mydotfiles
get_repo() {
  need git
  if [ ! -d "$DOTS/.git" ]; then
    msg "Cloning repo to $DOTS"
    git clone "$REPO" "$DOTS"
  else
    msg "Repo exists, pulling latest"
    git -C "$DOTS" pull --ff-only
  fi
}

# Copy hardware config into flake dir
cp_config() {
  [ -f "$NIX_CFG" ] || fail "hardware-configuration.nix not found at $NIX_CFG"
  msg "Copying $NIX_CFG -> $HOME/.mydotfiles/nixos/hardware-configuration.nix"
  sudo cp "$NIX_CFG" "$HOME/.mydotfiles/nixos/hardware-configuration.nix"
  sudo chown $USER:wheel "$HOME/.mydotfiles/nixos/hardware-configuration.nix"
}

# Rebuild with flakes enabled
first_rebuild() {
  msg "Rebuilding with flakes enabled (bootstrap)"
  sudo nixos-rebuild switch \
  --flake ~/.mydotfiles/nixos#voidgazer \
  --option experimental-features "nix-command flakes"
}

# Apply ML4W dotfiles
apply_ml4w() {
  if command -v apply-ml4w >/dev/null 2>&1; then
    msg "Applying ML4W dotfiles"
    apply-ml4w || warn "apply-ml4w returned non-zero (continuing)"
  else
    warn "apply-ml4w not in PATH yet, did your config add it? Skipping."
  fi
}

# Rust toolchain + matugen build
setup_rust_matugen() {
  if ! command -v rustup >/dev/null 2>&1; then
    msg "Installing rustup (user-level)"
    nix-env -iA nixpkgs.rustup || warn "Failed to install rustup via nix-env"
  fi

  if command -v rustup >/dev/null 2>&1; then
    msg "Setting default Rust toolchain to stable"
    rustup default stable || warn "rustup default stable failed (continuing)"
    msg "Installing matugen via cargo"
    if command -v cargo >/dev/null 2>&1; then
      cargo install matugen || warn "cargo install matugen failed (continuing)"
    else
      warn "cargo not found, is rustup initialized? Skipping matugen."
    fi
  fi
}

# Restore Flatpaks
restore_flatpaks() {
  if [ -f "$FLATPAKS" ]; then
    if command -v flatpaks-restore >/dev/null 2>&1; then
      msg "Restoring Flatpaks from $FLATPAKS"
      flatpaks-restore "$FLATPAKS" || warn "flatpaks-restore reported issues (continuing)"
    else
      warn "flatpaks-restore not in PATH, did your config add it? Skipping."
    fi
  else
    warn "Flatpaks CSV not found at $FLATPAKS (skipping restore)."
  fi

  # Update ML4W apps
  if systemctl list-unit-files | grep -q '^ml4w-flatpaks\.service'; then
    msg "Starting ml4w-flatpaks oneshot service"
    sudo systemctl start ml4w-flatpaks.service || warn "ml4w-flatpaks failed (continuing)"
  fi
}

### Run all steps
# Pass backup file path as $1 to restore home first
# (e.g., ~/Downloads)
restore_home "${1:-}"

get_repo
cp_config
first_rebuild
apply_ml4w
setup_rust_matugen
restore_flatpaks

#sneak in NAS sync folder
mkdir -p ~/Mjolnir

msg "All done. Reboot and enjoy!"
