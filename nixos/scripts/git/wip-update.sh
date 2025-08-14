#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.mydotfiles/nixos}"
HOST="${HOST:-voidgazer}"
BRANCH="${BRANCH:-main}"

cd "$FLAKE_DIR"

if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  git branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true
fi

git fetch --prune
counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")"
ahead="${counts%% *}"; behind="${counts##* }"
[[ "$ahead"  =~ ^[0-9]+$ ]] || ahead=0
[[ "$behind" =~ ^[0-9]+$ ]] || behind=0

if [ "$behind" -gt 0 ]; then
  git rebase --rebase-merges --autostash @{u} || {
    echo "Rebase failed. Resolve conflicts, then: git rebase --continue"
    exit 1
  }
fi

# Update flake inputs, stage lock+flake, keep WIP local (no push)
nix flake update "$FLAKE_DIR"
git add flake.lock flake.nix || true

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  git commit --amend --no-edit
else
  git commit -m "WIP"
fi

exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
