#!/usr/bin/env bash
set -euo pipefail
latest="$(ls -1t /var/log/nixos-updates/*.log 2>/dev/null | head -n1 || true)"
[ -n "${latest:-}" ] || exit 0
gnome-text-editor "$latest" >/dev/null 2>&1 &
