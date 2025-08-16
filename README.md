## Description
Long time Arch user wants to experiment with NixOS. ML4W doesn't have a NixOS install script. wut do.

## Notes
This repo is primarily for my own use. The instructions are wordy and verbose because I am forgetful lol

This is not a clean install of ML4W. It's going to install programs I use. `configuration.nix` has ML4W deps clearly marked so don't touch them. Edit anything else as you see fit.

If you've stumbled upon this repo: hi, good luck

## How to use
<details>
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

1. Grab your backup and restore:

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

## How it works

To edit system configuration use: ~/.mydotfiles/nixos/configuration.nix

A number of helpful scripts are provided:

### System

`apply-ml4w`: symlinks ML4W dotfiles into place

`flatpaks-restore` and `flatpaks-export`:

Use export before a backup/git push/reinstall (the backup script will do this automatically): `flatpaks-export ~/.mydotfiles/scripts/flatpaks.csv`

Use restore after (re)install (the installer script will do this automatically): `flatpaks-restore ~/.mydotfiles/scripts/flatpaks.csv`

### Git

After editing, do the standard `git add .` and `git commit -m "message"`. If the system doesn't build and you need to rebuild again (and again) the following are useful:

`wip-rebuild`: stage → single local WIP commit → switch

`wip-test`: stage → single local WIP commit → test

`git-sync "message"`: replace WIP with a real message → push

These will simply take care of git for you and rebuild so you don't end up pushing a bad edit. Once you rebuild successfully use `git sync`. Either add a new message or leave blank to use the message of your original commit. Adding a new message is recommended even if it's the same as your original `git commit` message.

### General

Inside `~/.mydotfiles/scripts` some very simple scripts are included.

`nix_install`: This is the installer, no need to touch once system is installed

`nix_clean`: This gives fine grained control of cleaning up the system. Just run with no arguments to see the options.

`nix_backup`: This script simply streams your entire `$HOME`, minus what is managed by ML4W, into a compressed tarball: `NixOS_Backup-$HOST-$DATE.tar.gz`. Use with caution if you have a lot of games, video, etc. Add `--exclude` entries as necessary. It will run `flatpaks-export` automatically.
