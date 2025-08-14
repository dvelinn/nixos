#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.mydotfiles/nixos}"
HOST="${HOST:-voidgazer}"
BRANCH="${BRANCH:-main}"

cd "$FLAKE_DIR"

# Ensure upstream tracking (e.g., main -> origin/main)
if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  git branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true
fi

git fetch --prune

# Compute ahead/behind; fallback to "0 0" if upstream is missing
counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")"
ahead="${counts%% *}"; behind="${counts##* }"
[[ "$ahead"  =~ ^[0-9]+$ ]] || ahead=0
[[ "$behind" =~ ^[0-9]+$ ]] || behind=0

# If behind, integrate before committing
if [ "$behind" -gt 0 ]; then
  git rebase --rebase-merges --autostash @{u}
fi

# Stage + commit (amend to keep WIP local; this script does not push)
git add -A
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git commit --amend --no-edit
else
  git commit -m "WIP"
fi

exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
