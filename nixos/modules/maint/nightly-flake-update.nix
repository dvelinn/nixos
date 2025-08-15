{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.services.nightlyFlakeUpdate;
in
{
  options.services.nightlyFlakeUpdate = {
    enable = mkEnableOption "Nightly flake.lock update then build/switch (no auto-commit)";
    user = mkOption {
      type = types.str;
      default = "polygon";
      description = "lock updates run as this user.";
    };
    repoPath = mkOption {
      type = types.str;
      example = "/home/polygon/.mydotfiles/nixos";
      description = "Path to the flake repo.";
    };
    host = mkOption {
      type = types.str;
      example = "voidgazer";
      description = "Flake output hostname";
    };
    onCalendar = mkOption {
      type = types.str;
      default = "*-*-* 03:00:00 America/New_York";
      description = "systemd OnCalendar schedule";
    };
    randomizedDelaySec = mkOption {
      type = types.str;
      default = "10m";
      description = "Jitter for the timer.";
    };
    installApproveHelper = mkOption {
      type = types.bool;
      default = true;
      description = "Install an approve-lock-update helper on PATH.";
    };
  };

  config = mkIf cfg.enable {
    # Let flakes carry settings without warnings
    nix.settings.accept-flake-config = true;

    # Service runs as root, but updates the lock as user to preserve ownership.
    systemd.services.nightly-flake-update-and-build = {
      description = "Nightly: update flake.lock (no commit) → nixos-rebuild switch; rollback lock on failure";
      wantedBy = [ "multi-user.target" ];

      # Ensure needed tools are on PATH for the service
      path = with pkgs; [
        bash coreutils git nix util-linux findutils gawk gnugrep sudo
      ];

      serviceConfig = {
        Type = "oneshot";
        # Leave as root so nixos-rebuild can run without sudo gymnastics
        # (we exec the update step as cfg.user inside the script).
        WorkingDirectory = cfg.repoPath;
        # Avoid noisy failures if the dir isn't present
        ConditionPathIsDirectory = cfg.repoPath;
      };

      script = ''
        set -euo pipefail

        REPO="${cfg.repoPath}"
        USER_NAME="${cfg.user}"
        HOST="${cfg.host}"

        if [ ! -d "$REPO" ]; then
          echo "[nightly] Repo path not found: $REPO"
          exit 0
        fi

        cd "$REPO"

        TS="$(date -Iseconds)"
        if [ -f flake.lock ]; then
          cp -f flake.lock "flake.lock.backup.$TS"
        fi

        echo "[nightly] Updating flake.lock as $USER_NAME (no commit)..."
        # Run update as the repo owner so ownership stays clean.
        # HOME is set to ensure flake config behaves as if user invoked it.
        ${pkgs.util-linux}/bin/runuser -u "$USER_NAME" -- \
          ${pkgs.bash}/bin/bash -lc "cd \"$REPO\" && HOME=/home/$USER_NAME nix flake update --flake ."

        echo "[nightly] Building & switching to $HOST from updated lock..."
        if ${config.system.build.nixos-rebuild}/bin/nixos-rebuild switch --flake "$REPO#$HOST"; then
          echo "[nightly] SUCCESS: system switched to new lock."
          exit 0
        else
          echo "[nightly] FAILURE: rebuild failed; restoring previous flake.lock."
          if [ -f "flake.lock.backup.$TS" ]; then
            mv -f "flake.lock.backup.$TS" flake.lock
            chown "$USER_NAME:wheel" flake.lock || true
            echo "[nightly] Restored prior flake.lock."
          else
            echo "[nightly] No backup lock found; nothing to restore."
          fi
          exit 1
        fi
      '';
    };

    systemd.timers.nightly-flake-update-and-build = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };
    };

    # Optional helper to approve lock update
    environment.systemPackages = mkIf cfg.installApproveHelper [
      (pkgs.writeShellScriptBin "approve-lock-update" ''
        set -euo pipefail
        cd "${cfg.repoPath}"

        if [ ! -f flake.lock ]; then
          echo "No flake.lock at ${cfg.repoPath}"
          exit 1
        fi

        git status --short
        git diff -- flake.lock || true

        read -rp "Commit current flake.lock and push? [y/N] " ans
        case "${ans:-N}" in
          y|Y)
            git add flake.lock
            if command -v jq >/dev/null 2>&1; then
              rev=$(jq -r '.nodes.nixpkgs.locked.rev // empty' flake.lock)
              git commit -m "Approve nightly flake.lock (${rev:-no-rev-found})"
            else
              git commit -m "Approve nightly flake.lock"
            fi
            git push
            echo "Approved and pushed."
            ;;
          *)
            echo "Aborted."
            ;;
        esac
      '')
      pkgs.git
      pkgs.jq
    ];
  };
}
