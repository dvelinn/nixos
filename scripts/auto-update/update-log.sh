#!/usr/bin/env bash
set -euo pipefail

LOG_DIR=/var/log/nixos-updates
STATE_DIR=/var/lib/nixos-update-report
mkdir -p "$LOG_DIR" "$STATE_DIR"

# Current and previous system generations
curr_path="$(readlink -f /nix/var/nix/profiles/system)"
cur_idx="$(readlink /nix/var/nix/profiles/system | sed -E 's/.*-([0-9]+)-link/\1/')"

# If this is the first gen or we can't parse, just exit quietly
if ! [[ "$cur_idx" =~ ^[0-9]+$ ]] || [ "$cur_idx" -le 0 ]; then
  exit 0
fi

prev_link="/nix/var/nix/profiles/system-$((cur_idx - 1))-link"
if [ ! -e "$prev_link" ]; then
  exit 0
fi
prev_path="$(readlink -f "$prev_link")"

# If no change, nothing to log
[ "$prev_path" = "$curr_path" ] && exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log="$LOG_DIR/update-$ts.log"

{
  echo "== NixOS auto-upgrade report $ts =="
  echo "Prev: $prev_path"
  echo "New : $curr_path"
  echo
  echo "== Package changes (prev -> new) =="
  nix store diff-closures "$prev_path" "$curr_path" || true
} > "$log"
