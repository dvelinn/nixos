{ config, lib, pkgs, ... }:

{
  # ----------------------------------------------------------------------------
  # Imports & host identity
  # ----------------------------------------------------------------------------
  imports = [  ./hardware-configuration.nix ];
  networking.hostName = "voidgazer";

  # Bash aliases for QoL
  environment.shellAliases = {
  update-flake = "nix flake update --flake ~/.mydotfiles/nixos";
  rebuild  = "sudo nixos-rebuild switch --flake ~/.mydotfiles/nixos#voidgazer";
  };

  # Install custom bash scripts
  programs.ml4wScripts.enable = true;
  programs.devScripts = {
  enable = true;
  scripts = {
    "wip-rebuild" = "/scripts/git/wip-rebuild.sh";
    "wip-test"    = "/scripts/git/wip-test.sh";
    "wip-update"  = "/scripts/git/wip-update.sh";
    "git-sync"    = "/scripts/git/git-sync.sh";
    };
  };


  # ----------------------------------------------------------------------------
  # Boot & kernel
  # ----------------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.kernelPackages = pkgs.linuxPackages_latest;  # defualt nixos kernel
  boot.loader.systemd-boot.configurationLimit = 5;
  programs.perfBalanced.enable = true;
  programs.perfBalanced.kernelFlavor = "zen";

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
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

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

  # Expose common shared data directories from packages
  environment.pathsToLink = [ "/share" ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  services.flatpak.enable = true;
  services.mullvad-vpn.enable = true;

  # ----------------------------------------------------------------------------
  # Basic maintenance
  # ----------------------------------------------------------------------------
  # Update lock file
  services.lockfileUpdater = {
    enable = true;
    user = "polygon";
    repoPath = "/home/polygon/.mydotfiles/nixos";
    onCalendar = "*-*-* 02:50:00 America/New_York"; # tweak if you like
  };

  # Build system
  system.autoUpgrade = {
    enable = true;
    flake = "/home/polygon/.mydotfiles/nixos#voidgazer";
    allowReboot = false;
    operation = "switch";
    persistent = true;
    dates = "*-*-* 03:00:00 America/New_York";
  };

  # Make sure the update log directory exists and is 0755
  systemd.tmpfiles.rules = [
    "d /var/log/nixos-updates 0755 root root -"
  ];

  # Create a log of what was updated
  programs.updateLog = {
    enable = true;
    script = "/home/polygon/.mydotfiles/scripts/auto-update/update-log.sh";
    schedule = "*-*-* 03:10:00 America/New_York";
    tieToAutoUpgrade = true;
  };

  # Run garbage collection on a weekly basis to avoid filling up disk
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # ----------------------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [

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
    plex-desktop

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
