{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf mkEnableOption mkOption types;
  cfg = config.services.lockfileUpdater;
in
{
  options.services.lockfileUpdater = {
    enable = mkEnableOption "Nightly nix flake update (no commit)";
    user = mkOption {
      type = types.str;
      default = "polygon";
      description = "Repo owner that will run nix flake update";
    };
    repoPath = mkOption {
      type = types.str;
      default = "/home/polygon/.mydotfiles/nixos";
      description = "Path to the flake root";
    };
    onCalendar = mkOption {
      type = types.str;
      # Run 10 minutes before your 03:00 local auto-upgrade
      default = "*-*-* 02:50:00 America/New_York";
      description = "systemd OnCalendar";
    };
    randomizedDelaySec = mkOption {
      type = types.str;
      default = "10m";
      description = "Optional jitter";
    };
  };

  config = mkIf cfg.enable {
    # Convenience so flakes with per-input settings don't warn
    nix.settings.accept-flake-config = true;

    systemd.services.lockfile-updater = {
      description = "Nightly: nix flake update (no commit)";
      wantedBy = [ "multi-user.target" ];
      # Tools available to the unit
      path = with pkgs; [ bash coreutils git nix util-linux ];

      serviceConfig = {
        Type = "oneshot";
        WorkingDirectory = cfg.repoPath;
        ConditionPathIsDirectory = cfg.repoPath;
      };

      script = ''
        set -euo pipefail
        REPO="${cfg.repoPath}"
        USER_NAME="${cfg.user}"

        if [ ! -d "$REPO" ]; then
          echo "[lockfile-updater] Missing repo path: $REPO"
          exit 0
        fi
        cd "$REPO"

        # Ensure the lockfile is writable by the repo owner
        [ -f flake.lock ] && chmod u+w flake.lock || true

        echo "[lockfile-updater] Updating flake.lock as $USER_NAME (no commit)..."
        ${pkgs.util-linux}/bin/runuser -u "$USER_NAME" -- \
          ${pkgs.bash}/bin/bash -lc "cd \"$REPO\" && HOME=/home/$USER_NAME nix flake update --flake ."

        echo "[lockfile-updater] Done."
      '';
    };

    systemd.timers.lockfile-updater = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
      };
    };
  };
}
