{ lib, pkgs, config, self, ... }:

let
  cfg = config.programs.devScripts;

  # Build a tiny package that copies a repo file into $out/bin/<name>
  mkBinFromSelf = name: relPath:
    pkgs.stdenvNoCC.mkDerivation {
      pname = name;
      version = "1.0";
      src = self + relPath;      # take the file directly from your flake repo
      dontUnpack = true;
      installPhase = ''
        mkdir -p "$out/bin"
        cp "$src" "$out/bin/${name}"
        chmod +x "$out/bin/${name}"
      '';
    };

  bins = lib.mapAttrsToList mkBinFromSelf cfg.scripts;
in {
  options.programs.devScripts = {
    enable = lib.mkEnableOption "Install external bash scripts from the repo";

    # Mapping: { "<binary-name>" = "/relative/path/from/flake/root"; }
    scripts = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = {};
      example = {
        "wip-rebuild" = "/scripts/git/wip-rebuild.sh";
        "wip-test"    = "/scripts/git/wip-test.sh";
        "wip-update"  = "/scripts/git/wip-update.sh";
        "git-sync"    = "/scripts/git/git-sync.sh";
      };
      description = "Binary name → repo-relative file path";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = bins;
  };
}
