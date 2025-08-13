#!/usr/bin/env bash
set -euo pipefail

# Options (defaults)
KEEP=""           # e.g. 5  → keep last 5 gens (system + current user)
DELETE_ALL=0      # 1      → delete all old gens (system + current user)
OPTIMISE=1        # run nix-store --optimise (hard-linking)
DRY_RUN=0
YES=0

usage() {
  cat <<EOF
Usage: $0 [--keep N | --delete-all] [--no-optimise] [--dry-run] [-y]

  --keep N         Keep the last N generations (system + current user).
  --delete-all     Delete all old generations (WARNING: no rollbacks).
  --no-optimise    Skip "nix-store --optimise".
  --dry-run        Show what would happen, make no changes.
  -y               Don't prompt for confirmation.

Examples:
  $0 --keep 5
  $0 --delete-all
  $0 --keep 10 --no-optimise
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP="${2:-}"; shift 2 ;;
    --delete-all) DELETE_ALL=1; shift ;;
    --no-optimise) OPTIMISE=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -y) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$KEEP" && $DELETE_ALL -ne 1 ]]; then
  echo "Pick one: --keep N  OR  --delete-all" >&2
  usage; exit 1
fi
if [[ -n "$KEEP" && $DELETE_ALL -eq 1 ]]; then
  echo "Can't use --keep and --delete-all together." >&2
  exit 1
fi
if [[ -n "$KEEP" && ! "$KEEP" =~ ^[0-9]+$ ]]; then
  echo "--keep requires a number." >&2
  exit 1
fi

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

confirm() {
  [[ $YES -eq 1 ]] && return 0
  read -r -p "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Helpers: list and prune generations
list_system_gens() {
  sudo nix-env -p /nix/var/nix/profiles/system --list-generations | awk '{print $1}'
}
list_user_gens() {
  nix-env --list-generations | awk '{print $1}'
}

delete_system_gens() {
  local gens="$1"
  [[ -z "$gens" ]] && return 0
  run "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations $gens"
}
delete_user_gens() {
  local gens="$1"
  [[ -z "$gens" ]] && return 0
  run "nix-env --delete-generations $gens"
}

keep_last_n() {
  local n="$1"
  local which="$2"  # "system" or "user"

  local gens all del
  if [[ "$which" == "system" ]]; then
    all=($(list_system_gens))
  else
    all=($(list_user_gens))
  fi
  local count=${#all[@]}
  if (( count <= n )); then
    echo "[$which] $count generations <= keep $n → nothing to delete."
    return 0
  fi
  # delete everything except the last N
  del="${all[@]:0:count-n}"
  echo "[$which] keeping last $n of $count; deleting: $del"
  if [[ "$which" == "system" ]]; then
    delete_system_gens "$del"
  else
    delete_user_gens "$del"
  fi
}

delete_all_old() {
  echo "[system] nix-collect-garbage -d"
  run "sudo nix-collect-garbage -d"
  echo "[user] nix-collect-garbage -d"
  run "nix-collect-garbage -d"
}

optimise_store() {
  echo "[store] nix-store --optimise (hard-linking identical files)"
  run "sudo nix-store --optimise"
}

# Show plan
echo "=== nix-clean plan ==="
if [[ $DELETE_ALL -eq 1 ]]; then
  echo "Action: delete ALL old generations (system + current user)"
else
  echo "Action: keep last $KEEP generations (system + current user)"
fi
echo "Optimise: $([[ $OPTIMISE -eq 1 ]] && echo yes || echo no)"
echo "Dry-run:  $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
echo

confirm "Proceed?" || { echo "Aborted."; exit 1; }

# Execute
if [[ $DELETE_ALL -eq 1 ]]; then
  delete_all_old
else
  keep_last_n "$KEEP" "system"
  keep_last_n "$KEEP" "user"
fi

if [[ $OPTIMISE -eq 1 ]]; then
  optimise_store
fi

echo "Done."
