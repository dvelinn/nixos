#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="${FLAKE_DIR:-$HOME/.mydotfiles/nixos}"
BRANCH="${BRANCH:-main}"
cd "$FLAKE_DIR"

msg="$*"; [ -z "$msg" ] && msg="Checkpoint"

# Ensure upstream tracking
if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
  git branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true
fi

git fetch --prune
counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")"
ahead="${counts%% *}"; behind="${counts##* }"
[[ "$ahead"  =~ ^[0-9]+$ ]] || ahead=0
[[ "$behind" =~ ^[0-9]+$ ]] || behind=0

# If behind, integrate first
if [ "$behind" -gt 0 ]; then
  git rebase --rebase-merges --autostash @{u} || {
    echo "Rebase failed. Resolve conflicts, then: git rebase --continue"
    exit 1
  }
  # recompute
  counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")"
  ahead="${counts%% *}"; behind="${counts##* }"
  [[ "$ahead"  =~ ^[0-9]+$ ]] || ahead=0
  [[ "$behind" =~ ^[0-9]+$ ]] || behind=0
fi

git add -A
if ! git diff --quiet --cached --exit-code; then
  if [ "$ahead" -eq 0 ]; then
    # Up-to-date with origin -> create a NEW commit (fast-forward push)
    git commit -m "$msg"
  else
    # Local commits not yet on origin -> amend to keep WIP squashed
    git commit --amend -m "$msg"
  fi
fi

# Try normal push (should be FF most of the time)
if git push; then
  echo "Pushed: $msg"
  exit 0
fi

# Fallback for races: refresh, rebase, push
git fetch --prune
if git rebase --rebase-merges --autostash @{u}; then
  if git push; then
    echo "Pushed after rebase: $msg"
    exit 0
  fi
fi

# Last resort: lease-protected force (won't clobber others)
echo "Normal push rejected; retrying with --force-with-lease..."
git push --force-with-lease
echo "Pushed (with lease): $msg"
