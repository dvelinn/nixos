{ config, lib, pkgs, ... }:

# ----------------------------------------------------------------------------
# Helper scripts & external inputs (let/in)
# ----------------------------------------------------------------------------
let
  # ML4W dotfile linker
  linkScript = pkgs.writeShellScriptBin "apply-ml4w" ''
    set -euo pipefail
    SRC="$HOME/.mydotfiles/com.ml4w.dotfiles.stable"
    HOME_DIR="$HOME"
    CFG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}"
    mkdir -p "$CFG_DIR"

    # Top-level dotfiles into $HOME
    for f in .bashrc .gtkrc-2.0 .Xresources .zshrc; do
      [ -e "$SRC/$f" ] && ln -sfn "$SRC/$f" "$HOME_DIR/$f"
    done

    # Everything under .config/ into $XDG_CONFIG_HOME
    if [ -d "$SRC/.config" ]; then
      shopt -s nullglob dotglob
      for item in "$SRC/.config"/*; do
        name="$(basename "$item")"
        ln -sfn "$item" "$CFG_DIR/$name"
      done
    fi

    echo "ML4W dotfiles applied for $HOME_DIR"
  '';

  # Flatpak export helper (excludes ML4W apps)
  flatpaksExport = pkgs.writeShellScriptBin "flatpaks-export" ''
    set -euo pipefail
    out="''${1:-flatpaks.csv}"
    tmp="$(${pkgs.coreutils}/bin/mktemp)"
    ${pkgs.flatpak}/bin/flatpak list --app --columns=application,origin,installation > "$tmp"
    ${pkgs.gnugrep}/bin/grep -v -E '^(com\.ml4w\.(welcome|settings|sidebar|calendar|hyprlandsettings))\s' "$tmp" > "$out"
    ${pkgs.coreutils}/bin/rm -f "$tmp"
    echo "Wrote Flatpak list to: $out"
  '';

  # Flatpak restore helper (reads CSV and installs system/user scopes)
  flatpaksRestore = pkgs.writeShellScriptBin "flatpaks-restore" ''
    set -euo pipefail
    file="''${1:-flatpaks.csv}"
    if [ ! -f "$file" ]; then
      echo "Usage: flatpaks-restore <csv>" >&2
      exit 1
    fi
    FLATPAK=${pkgs.flatpak}/bin/flatpak
    AWK=${pkgs.gawk}/bin/awk

    # Ensure flathub exists in both scopes
    $FLATPAK remote-add --if-not-exists --user   flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    $FLATPAK remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

    # Read csv, skip ML4W apps
    while IFS=$'\t' read -r app remote scope; do
      [ -n "''${app:-}" ] || continue
      case "$app" in
        com.ml4w.welcome|com.ml4w.settings|com.ml4w.sidebar|com.ml4w.calendar|com.ml4w.hyprlandsettings) continue ;;
      esac
      if [ "''${scope:-user}" = "system" ]; then scopeFlag="--system"; else scopeFlag="--user"; fi
      remote="''${remote:-flathub}"
      echo "Installing: $app from $remote ($scopeFlag)"
      $FLATPAK install -y --noninteractive --or-update $scopeFlag "$remote" "$app" || true
    done < <( $AWK -F'\t' 'NF>=1 {print $0}' "$file" )

    echo "Done restoring Flatpaks."
  '';

  FLAKE_DIR = "$HOME/.mydotfiles/nixos";  # adjust if you move your repo
  HOST      = "voidgazer";                # flake host

  # Stage with local commit, rebuild switch
  wipRebuild = pkgs.writeShellScriptBin "wip-rebuild" ''
    #!/usr/bin/env bash
    set -euo pipefail
    FLAKE_DIR="$HOME/.mydotfiles/nixos"
    HOST="voidgazer"
    cd "$FLAKE_DIR"
    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi
    exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
  '';

  # Stage with local commit, rebuild test
  wipTest = pkgs.writeShellScriptBin "wip-test" ''
    #!/usr/bin/env bash
    set -euo pipefail
    FLAKE_DIR="$HOME/.mydotfiles/nixos"
    HOST="voidgazer"
    cd "$FLAKE_DIR"
    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi
    exec sudo nixos-rebuild test --flake "$FLAKE_DIR#$HOST"
  '';

  # flake update, add new .lock, local commit, rebuild switch
  wipUpdate = pkgs.writeShellScriptBin "wip-update" ''
    #!/usr/bin/env bash
    set -euo pipefail
    FLAKE_DIR="$HOME/.mydotfiles/nixos"
    HOST="voidgazer"
    cd "$FLAKE_DIR"
    nix flake update
    git add flake.lock flake.nix || true
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend --no-edit
    else
      git commit -m "WIP"
    fi
    exec sudo nixos-rebuild switch --flake "$FLAKE_DIR#$HOST"
  '';

  # Actually push all WIP changes with a message
  checkpoint = pkgs.writeShellScriptBin "checkpoint" ''
    #!/usr/bin/env bash
    set -euo pipefail
    FLAKE_DIR="$HOME/.mydotfiles/nixos"
    cd "$FLAKE_DIR"
    msg="$*"
    if [ -z "$msg" ]; then msg="Checkpoint"; fi
    git add -A
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      git commit --amend -m "$msg"
    else
      git commit -m "$msg"
    fi
    git push
    echo "Pushed: $msg"
  '';

in

{
  # ----------------------------------------------------------------------------
  # Imports & host identity
  # ----------------------------------------------------------------------------
  imports = [ ./hardware-configuration.nix ];
  networking.hostName = "voidgazer";

  # Bash aliases for QoL and taming git with flakes
  environment.shellAliases = {
    rebuild-update = "nix flake update ~/.mydotfiles/nixos && sudo nixos-rebuild switch --flake ~/.mydotfiles/nixos#voidgazer";
    rebuild  = "sudo nixos-rebuild switch --flake ~/.mydotfiles/nixos#voidgazer";
  };

  # ----------------------------------------------------------------------------
  # Boot & kernel
  # ----------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;  # use latest kernel
  boot.loader.systemd-boot.configurationLimit = 3;

  # ----------------------------------------------------------------------------
  # Locale, time, networking
  # ----------------------------------------------------------------------------
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS       = "en_US.UTF-8";
    LC_IDENTIFICATION= "en_US.UTF-8";
    LC_MEASUREMENT   = "en_US.UTF-8";
    LC_MONETARY      = "en_US.UTF-8";
    LC_NAME          = "en_US.UTF-8";
    LC_NUMERIC       = "en_US.UTF-8";
    LC_PAPER         = "en_US.UTF-8";
    LC_TELEPHONE     = "en_US.UTF-8";
    LC_TIME          = "en_US.UTF-8";
  };
  networking.networkmanager.enable = true;

  # ----------------------------------------------------------------------------
  # Nix & nixpkgs policy
  # ----------------------------------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ----------------------------------------------------------------------------
  # NVIDIA & X/Wayland
  # ----------------------------------------------------------------------------
  hardware.graphics.enable = true;                # OpenGL
  services.xserver.videoDrivers = [ "nvidia" ];  # load NVIDIA driver
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;                 # should be true, but currently doesn't build
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # X11 display server + Gnome
  services.xserver.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Setup sddm theme
  environment.etc."sddm/themes/sugar-candy".source = ../assets/sugar-candy;

  # Enable sddm
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;        # crashes on wayland
    package = pkgs.libsForQt5.sddm;
      settings = {
        Theme = {
          ThemeDir = "/etc/sddm/themes";
          Current  = "sugar-candy";
        };
      };
    };

  # Hyprland compositor
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Portals (Wayland clipboard/open dialogs)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland xdg-desktop-portal-gtk ];
    config.common.default = [ "hyprland" "gtk" ];
  };

  # GTK/Electron session tweaks
  environment.sessionVariables = {
    GDK_BACKEND   = "wayland";  # keep Wayland-native for GTK apps
    GDK_GL        = "gles";     # Totem fix: use GLES on Wayland
    GTK_USE_PORTAL= "1";        # make GTK use portals
    NIXOS_OZONE_WL= "1";        # Electron/Chromium → Wayland
  };

  # ----------------------------------------------------------------------------
  # Input, audio, and desktop niceties
  # ----------------------------------------------------------------------------
  services.xserver.xkb = { layout = "us"; variant = ""; };
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true;  # uncomment if needed
  };

  # ----------------------------------------------------------------------------
  # Users
  # ----------------------------------------------------------------------------
  users.users.polygon = {
    isNormalUser = true;
    description  = "polygon";
    extraGroups  = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      # thunderbird
    ];
  };

  # ----------------------------------------------------------------------------
  # System programs & policies
  # ----------------------------------------------------------------------------
  programs.firefox.enable = true;

  # 1Password (GUI) from unstable; allow browser integration
  programs._1password-gui = {
    enable = true;
    # package = pkgs-unstable._1password-gui;
    package = pkgs._1password-gui;
    polkitPolicyOwners = [ "polygon" ];
  };
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      .zen-beta-wrapp
      zen-bin
      zen
    '';
    mode = "0644";
  };

  # PATH fix so flatpak apps are invokable & flatpak stops whining
  environment.extraInit = ''
    export PATH="$HOME/.local/share/flatpak/exports/bin:/var/lib/flatpak/exports/bin:$PATH"
  '';

  # Expose common shared data directories from packages
  environment.pathsToLink = [ "/share" ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  services.flatpak.enable = true;
  services.mullvad-vpn.enable = true;

  # One-shot service to add ML4W repo and install ML4W Flatpaks
  systemd.services.ml4w-flatpaks = {
    description = "Install/Update ML4W Flatpaks";
    wantedBy = [ "multi-user.target" ];
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ml4w-flatpaks.sh" ''
        set -euo pipefail
        FLATPAK=${pkgs.flatpak}/bin/flatpak
        CURL=${pkgs.curl}/bin/curl
        GREP=${pkgs.gnugrep}/bin/grep
        MKDIR=${pkgs.coreutils}/bin/mkdir
        MKTEMP=${pkgs.coreutils}/bin/mktemp
        RM=${pkgs.coreutils}/bin/rm

        # Ensure remotes exist
        if ! $FLATPAK remotes --system | $GREP -q '^flathub'; then
          $FLATPAK remote-add --if-not-exists --system flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
        fi

        tmp_key="$($MKTEMP)"
        $MKDIR -p /var/cache
        $CURL -fsSL "https://mylinuxforwork.github.io/ml4w-flatpak-repo/ml4w-apps-public-key.asc" -o "$tmp_key"

        if ! $FLATPAK remotes --system | $GREP -q '^ml4w-repo'; then
          $FLATPAK remote-add --if-not-exists --system ml4w-repo \
            https://mylinuxforwork.github.io/ml4w-flatpak-repo/ml4w-apps.flatpakrepo \
            --gpg-import="$tmp_key"
        fi
        $RM -f "$tmp_key"

        # Install/update ML4W apps
        $FLATPAK install -y --system --or-update ml4w-repo \
          com.ml4w.welcome \
          com.ml4w.settings \
          com.ml4w.sidebar \
          com.ml4w.calendar \
          com.ml4w.hyprlandsettings
      '';
    };
  };

  # ----------------------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # Personal helpers
    linkScript              # apply-ml4w
    flatpaksExport     # export Flatpak list
    flatpaksRestore   # restore Flatpaks from CSV
    wipRebuild           # stage → single local WIP commit → switch
    wipTest                  # stage → single local WIP commit → test
    wipUpdate          # flake update → record lock in WIP → switch
    checkpoint          # replace WIP with a real message → push

    # Apps
    mullvad-vpn
    gammastep
    zen-browser         # Zen browser (from flake)
    kdePackages.kate
    kdePackages.ghostwriter
    kdePackages.filelight
    quick-webapps
    freetube
    libreoffice-fresh
    gnome-calculator
    qt5.qtgraphicaleffects

    # == ML4W DEPS ==
    wget unzip gum rsync git figlet xdg-user-dirs
    hyprland hyprpaper hyprlock hypridle hyprpicker
    noto-fonts noto-fonts-emoji noto-fonts-cjk-sans noto-fonts-extra
    libnotify kitty fastfetch eza
    python313Packages.pip python313Packages.pygobject3 python313Packages.screeninfo
    xfce.tumbler brightnessctl networkmanagerapplet imagemagick jq xclip
    kitty neovim htop blueman grim slurp cliphist nwg-look qt6ct waybar rofi-wayland
    polkit_gnome zsh zsh-completions fzf pavucontrol papirus-icon-theme
    kdePackages.breeze swaynotificationcenter gvfs gnome.gvfs wlogout waypaper
    grimblast bibata-cursors font-awesome fira fira-code nerd-fonts.fira-code
    dejavu_fonts nwg-dock-hyprland power-profiles-daemon pywalfox-native vlc
    oh-my-posh wallust rustup gcc
    # == ML4W DEPS ==
  ];

  # ----------------------------------------------------------------------------
  # Firewall / SSH / extras
  # ----------------------------------------------------------------------------
  # services.printing.enable = true;
  # services.openssh.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # ----------------------------------------------------------------------------
  # State version (do not bump blindly)
  # ----------------------------------------------------------------------------
  system.stateVersion = "25.05";  # Did you read the comment?
}
