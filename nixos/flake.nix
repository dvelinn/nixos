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

      modules = [
        # Use 1Password from unstable
        ({ ... }: {
          nixpkgs.overlays = [
            # Use 1Password from unstable
            (final: prev: {
              _1password-gui = pkgsUnstable._1password-gui;
            })

            # Zen flake
            (final: prev: {
              zen-browser = zen.packages.${system}.default;
            })
          ];
        })

        # Load config
        ./configuration.nix
        ./modules/dev/helpers.nix
        ./modules/dev/ml4w.nix
      ];
    };
  };
}
