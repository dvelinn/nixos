#!/usr/bin/env bash
set -euo pipefail
out="${1:-flatpaks.csv}"
tmp="$(mktemp)"
flatpak list --app --columns=application,origin,installation > "$tmp"
grep -v -E '^(com\.ml4w\.(welcome|settings|sidebar|calendar|hyprlandsettings))\s' "$tmp" > "$out"
rm -f "$tmp"
echo "Wrote Flatpak list to: $out"
