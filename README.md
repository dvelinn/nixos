### Description
Long time Arch user wants to experiment with NixOS. ML4W doesn't have a NixOS install script. wut do.

### Notes
This repo is primarily for my own use. The instructions are wordy and verbose because I am forgetful lol

This is not a clean install of ML4W. It's going to install programs I use. `configuration.nix` has ML4W deps clearly marked so don't touch them. Edit anything else as you see fit. I've also cheated a bit and embedded a couple bash scripts into `configuration.nix` because I know bash a lot better than Nix, but it (finally) works so I'm filing it under "gets the job done."

If you've stumbled upon this repo: hi, good luck

### How to use
<details open>
<summary>Automated</summary>

These instructions assume a fresh install

1. (Optional) If you used the included backup script grab your backup and stick it somewhere (e.g., ~/Downloads)
2. Run the installer:

	`bash <(curl -fsSL https://raw.githubusercontent.com/dvelinn/nixos/main/scripts/nix_install.sh)`
	
	Or, optionally, point the installer at a backup
	
	`bash <(curl -fsSL https://raw.githubusercontent.com/dvelinn/nixos/main/scripts/nix_install.sh) ~/Downloads/backup.tar.gz`

Reboot and enjoy!
</details>

<details>
<summary>Manual</summary>

These are the exact commands nix_install.sh runs

1. Grab backup from NAS and restore:

	`tar -xpzf <backup> --xattrs --acls --numeric-owner -C "$HOME"`

2. Clone this repo: 
	
	`nix-shell -p git`
	
	`git clone https://github.com/dvelinn/nixos.git ~/.mydotfiles`

3. Copy hardware-configuration.nix to flake dir and set ownership:

	`sudo cp /etc/nixos/hardware-configuration.nix /home/<user>/.mydotfiles/nixos/hardware-configuration.nix`
	
	`sudo chown $USER:wheel /home/<user>/.mydotfiles/nixos/hardware-configuration.nix`

4. Rebuild the system and enable flakes:

	`sudo nixos-rebuild switch --flake ~/.mydotfiles/nixos#voidgazer --option experimental-features "nix-command flakes"`

5. Apply ML4W dots:

	run: `apply-ml4w`

6. Build matugen (will figure a better way later):

	`rustup default stable`
	
	`cargo install matugen`
	
7. Restore flatpaks

	run: `flatpaks-restore`

Reboot and enjoy!
</details>

### How it works

`configuration.nix` provides a number of scripts:

`apply-ml4w`: symlinks ML4W dotfiles into place

`flatpaks-restore` and `flatpaks-export`:

Use export before a backup/git push/reinstall (the backup script will do this automatically): `flatpaks-export ~/.mydotfiles/scripts/flatpaks.csv`

Use restore after (re)install (the installer script will do this automatically): `flatpaks-restore ~/.mydotfiles/scripts/flatpaks.csv`

And a series of scripts for working with git:

`wip-rebuild`: stage → single local WIP commit → switch

`wip-test`: stage → single local WIP commit → test

`wip-update`: flake update → record lock in WIP → switch

`checkpoint`: replace WIP with a real message → push

To edit system configuration use: ~/.mydotfiles/nixos/configuration.nix

Inside `~/.mydotfiles/scripts` a very simple backup script is included. It will run `flatpaks-export` automatically.

This script simply streams your entire `$HOME`, minus what is managed by ML4W, into a compressed tarball: `NixOS_Backup-$HOST-$DATE.tar.gz`. Use with caution if you have a lot of games, video, etc. Add `--exclude` entries as necessary.
