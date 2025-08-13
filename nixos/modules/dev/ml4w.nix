# modules/dev/ml4w.nix
{ lib, pkgs, config, ... }:

let
  # ML4W dotfile linker
  linkScript = pkgs.writeShellScriptBin "apply-ml4w" ''
    set -euo pipefail
    SRC="$HOME/.mydotfiles/com.ml4w.dotfiles.stable"
    HOME_DIR="$HOME"
    CFG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}"
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
  '';

  # Flatpak export helper
  flatpaksExport = pkgs.writeShellScriptBin "flatpaks-export" ''
    set -euo pipefail
    out="''${1:-flatpaks.csv}"
    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.flatpak}/bin/flatpak list --app --columns=application,origin,installation > "$tmp"
    ${pkgs.gnugrep}/bin/grep -v -E '^(com\.ml4w\.(welcome|settings|sidebar|calendar|hyprlandsettings))\s' "$tmp" > "$out"
    ${pkgs.coreutils}/bin/rm -f "$tmp"
    echo "Wrote Flatpak list to: $out"
  '';

  # Flatpak restore helper
  flatpaksRestore = pkgs.writeShellScriptBin "flatpaks-restore" ''
    set -euo pipefail
    file="''${1:-flatpaks.csv}"
    if [ ! -f "$file" ]; then
      echo "Usage: flatpaks-restore <csv>" >&2
      exit 1
    fi
    FLATPAK=${pkgs.flatpak}/bin/flatpak
    AWK=${pkgs.gawk}/bin/awk

    # Ensure flathub exists in both scopes
    $FLATPAK remote-add --if-not-exists --user   flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    $FLATPAK remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

    # Read csv, skip ML4W apps
    while IFS=$'\t' read -r app remote scope; do
      [ -n "''${app:-}" ] || continue
      case "$app" in
        com.ml4w.welcome|com.ml4w.settings|com.ml4w.sidebar|com.ml4w.calendar|com.ml4w.hyprlandsettings) continue ;;
      esac
      if [ "''${scope:-user}" = "system" ]; then scopeFlag="--system"; else scopeFlag="--user"; fi
      remote="''${remote:-flathub}"
      echo "Installing: $app from $remote ($scopeFlag)"
      $FLATPAK install -y --noninteractive --or-update $scopeFlag "$remote" "$app" || true
    done < <( $AWK -F'\t' 'NF>=1 {print $0}' "$file" )

    echo "Done restoring Flatpaks."
  '';
in
{
  options.programs.ml4w = {
    enable = lib.mkEnableOption "ML4W dotfile linker and Flatpak export/restore helpers";
  };

  config = lib.mkIf config.programs.ml4w.enable {
    environment.systemPackages = [
      linkScript
      flatpaksExport
      flatpaksRestore
    ];

    # ensure flatpak is enabled
    services.flatpak.enable = lib.mkDefault true;
  };
}
