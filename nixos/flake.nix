{
  description = "NixOS system flake";

  inputs = {
    nixpkgs.url          = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen.url              = "github:0xc000022070/zen-browser-flake";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, zen, ... }:
  let
    system       = "x86_64-linux";
    pkgs         = import nixpkgs          { inherit system; config.allowUnfree = true; };
    pkgsUnstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
  in {
    nixosConfigurations.voidgazer = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self; };

      modules = [
        # Overlay(s)
        ({ ... }: {
          nixpkgs.overlays = [
            # 1Password from unstable
            (final: prev: {
              _1password-gui = pkgsUnstable._1password-gui;
            })

            # Zen Browser from flake
            (final: prev: {
              zen-browser = zen.packages.${system}.default;
            })
          ];
        })

        # System config + modules
        ./configuration.nix
        ./modules/dev/git-scripts.nix
        ./modules/dev/helpers.nix
        ./modules/perf/balanced.nix
        ./modules/maint/update-log.nix
        ./modules/ml4w/flatpaks.nix
      ];
    };
  };
}
