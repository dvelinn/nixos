{ config, lib, pkgs, ... }:

{
  # Update ML4W flatpaks
  systemd.services.ml4w-flatpaks = {
    description = "Install/Update ML4W Flatpaks";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
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

  # Weekly timer to trigger the service
  systemd.timers.ml4w-flatpaks = {
    description = "Weekly ML4W Flatpak install/update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";   # runs once a week (Sun 00:00 by default)
      Persistent = true;       # catch up if missed while powered off
    };
  };
}
