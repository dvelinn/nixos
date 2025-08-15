# nixos/modules/dev/ml4w.nix
{ lib, config, ... }:

{
  options.programs.ml4wScripts = {
    enable = lib.mkEnableOption "Install ML4W + Flatpak helper scripts from repo files";
  };

  config = lib.mkIf config.programs.ml4wScripts.enable {
    programs.devScripts.scripts = {
      "apply-ml4w"       = "/scripts/ml4w/apply-ml4w.sh";
      "flatpaks-export"  = "/scripts/flatpak/flatpaks-export.sh";
      "flatpaks-restore" = "/scripts/flatpak/flatpaks-restore.sh";
    };

    # ensure Flatpak service is present
    services.flatpak.enable = lib.mkDefault true;
  };
}
