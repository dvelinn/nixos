# modules/dev/helpers.nix
{ lib, pkgs, config, ... }:

let
  cfg = config.programs.devHelpers;

  # ----------------------------------------------------------------------------
  # git helper scripts
  # ----------------------------------------------------------------------------
  # small bash snippet reused in scripts: fetch + compute ahead/behind safely
  syncPrelude = ''
    git fetch --prune

    # Read "ahead behind"; fall back to "0 0" if no upstream, etc.
    counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null || echo "0 0")"
    ahead="''${counts%% *}"
    behind="''${counts##* }"

    # Sanitize to integers with regex
    if [[ ! ''${ahead}  =~ ^[0-9]+$ ]];  then ahead=0;  fi
    if [[ ! ''${behind} =~ ^[0-9]+$ ]]; then behind=0; fi
  '';

  wipRebuild = pkgs.writeShellScriptBin "wip-rebuild" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_DIR="${cfg.flakeDir}"
    HOST="${cfg.host}"
    cd "$FLAKE_DIR"

    # Ensure upstream tracking (e.g., main -> origin/main)
    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      git branch --set-upstream-to=origin/${cfg.branch} ${cfg.branch} >/dev/null 2>&1 || true
    fi

    ${syncPrelude}

    # If we're behind, rebase; FF is a no-op for rebase.
    if [ ''${behind} -gt 0 ]; then
      git rebase --rebase-merges --autostash @{u}
    fi

    # Stage + commit (amend if history exists)
    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi

    exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
  '';

  wipTest = pkgs.writeShellScriptBin "wip-test" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_DIR="${cfg.flakeDir}"
    HOST="${cfg.host}"
    cd "$FLAKE_DIR"

    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      git branch --set-upstream-to=origin/${cfg.branch} ${cfg.branch} >/dev/null 2>&1 || true
    fi

    ${syncPrelude}

    if [ ''${behind} -gt 0 ]; then
      git rebase --rebase-merges --autostash @{u} || {
        echo "Rebase failed. Resolve conflicts, then: git rebase --continue"
        exit 1
      }
    fi

    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi

    exec sudo nixos-rebuild test --flake "$FLAKE_DIR#$HOST"
  '';

  wipUpdate = pkgs.writeShellScriptBin "wip-update" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_DIR="${cfg.flakeDir}"
    HOST="${cfg.host}"
    cd "$FLAKE_DIR"

    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      git branch --set-upstream-to=origin/${cfg.branch} ${cfg.branch} >/dev/null 2>&1 || true
    fi

    ${syncPrelude}
    if [ ''${behind} -gt 0 ]; then
      git rebase --rebase-merges --autostash @{u} || {
        echo "Rebase failed. Resolve conflicts, then: git rebase --continue"
        exit 1
      }
    fi

    nix flake update "$FLAKE_DIR"
    git add flake.lock flake.nix || true

    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi

    exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
  '';

  checkpoint = pkgs.writeShellScriptBin "checkpoint" ''
    #!/usr/bin/env bash
    set -euo pipefail

    FLAKE_DIR="${cfg.flakeDir}"
    cd "$FLAKE_DIR"

    msg="$*"; if [ -z "$msg" ]; then msg="Checkpoint"; fi

    if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      git branch --set-upstream-to=origin/${cfg.branch} ${cfg.branch} >/dev/null 2>&1 || true
    fi

    ${syncPrelude}
    if [ ''${behind} -gt 0 ]; then
      git rebase --rebase-merges --autostash @{u} || {
        echo "Rebase failed. Resolve conflicts then run: git rebase --continue"
        exit 1
      }
    fi

    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend -m "$msg"
    else
      git commit -m "$msg"
    fi

    if git push; then
      echo "Pushed: $msg"
      exit 0
    fi
    echo "Normal push rejected; retrying with --force-with-lease..."
    git push --force-with-lease
    echo "Pushed (with lease): $msg"
  '';
in
{
  options.programs.devHelpers = {
    enable = lib.mkEnableOption "git helper scripts";

    flakeDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.mydotfiles/nixos";
      description = "flake repo";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "voidgazer";
      description = "hostname";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "branch";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      wipRebuild
      wipTest
      wipUpdate
      checkpoint
    ];
  };
}
