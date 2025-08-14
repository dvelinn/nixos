{ config, lib, pkgs, ... }:

let
  cfg = config.programs.updateLog;
in
{
  options.programs.updateLog = {
    enable = lib.mkEnableOption "Run a post-upgrade report script on a schedule";

    # Absolute path to bash script that writes the log
    script = lib.mkOption {
      type = lib.types.str;
      example = "/home/polygon/.mydotfiles/scripts/auto-update/update-log.sh";
      description = "Absolute path to the update-log.sh script.";
    };

    # Systemd OnCalendar format; run it a few minutes after system.autoUpgrade
    schedule = lib.mkOption {
      type = lib.types.str;
      default = "07:10";
      example = "Sun *-*-* 03:40:00";
      description = "When to run the report (systemd OnCalendar syntax).";
    };

    # Add Wants/After on the built-in timer
    tieToAutoUpgrade = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "If true, add Wants/After=nixos-upgrade.timer so the report is tied to the built-in updater.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nixos-update-log = {
      description = "Log package changes after daily auto-upgrade";
      # Tie to the built-in updater timer
      wants = lib.mkIf cfg.tieToAutoUpgrade [ "nixos-upgrade.timer" ];
      after  = lib.mkIf cfg.tieToAutoUpgrade [ "nixos-upgrade.timer" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = cfg.script;
      };
    };

    systemd.timers.nixos-update-log = {
      description = "Run NixOS update-report after auto-upgrade";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        Persistent = true;
      };
    };
  };
}
