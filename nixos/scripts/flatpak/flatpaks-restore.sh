#!/usr/bin/env bash
set -euo pipefail
file="${1:-flatpaks.csv}"
if [ ! -f "$file" ]; then
  echo "Usage: flatpaks-restore <csv>" >&2
  exit 1
fi

FLATPAK=flatpak
AWK=awk

# Ensure flathub exists in both scopes
$FLATPAK remote-add --if-not-exists --user   flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
$FLATPAK remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Read csv, skip ML4W apps
while IFS=$'\t' read -r app remote scope; do
  [ -n "${app:-}" ] || continue
  case "$app" in
    com.ml4w.welcome|com.ml4w.settings|com.ml4w.sidebar|com.ml4w.calendar|com.ml4w.hyprlandsettings) continue ;;
  esac
  if [ "${scope:-user}" = "system" ]; then scopeFlag="--system"; else scopeFlag="--user"; fi
  remote="${remote:-flathub}"
  echo "Installing: $app from $remote ($scopeFlag)"
  $FLATPAK install -y --noninteractive --or-update $scopeFlag "$remote" "$app" || true
done < <( $AWK -F'\t' 'NF>=1 {print $0}' "$file" )

echo "Done restoring Flatpaks."
