# Set up the Steam Deck

The Steam Deck runs Valve's SteamOS, which this repo does not manage as NixOS: Valve's update
model is what keeps the gaming environment working. It gets the shared environment another way.
`lib/mkhome.nix` builds `homeConfigurations.deck`: the same `home/` as every machine, as a
standalone home-manager, applied on the Deck itself.

What this repo asks of SteamOS: the official Nix installer, its user `deck`, bash as the login
shell. What it does not touch: system services, `/etc`, Steam and Proton. Those are Stage 2
(see [Roadmap](roadmap.md#steam-deck)) and are written there when they happen.

## What you need

- The Steam Deck, with SteamOS current (Settings > System > System updates)
- A USB-C dock or hub with a keyboard, for the console access the recovery needs
- The Mac, with the configuration applied

## Put Nix on the Steam Deck

1. Switch to Desktop Mode. Open Konsole.
2. Set a password for `deck`. It has none until you do, and everything later needs `sudo`.

   ```sh
   passwd
   ```

3. Install Nix with the official installer's Steam Deck mode. It keeps the store in `/home/nix`,
   which an update keeps, mounts it on `/nix` at each boot, and writes its own
   `/etc/atomic-update.conf.d/nix-installer.conf` keep-list entry.

   ```sh
   sudo steamos-readonly disable
   sudo mkdir -p /etc/tmpfiles.d
   curl -fsSL https://artifacts.nixos.org/nix-installer -o /tmp/nix-installer.sh
   less /tmp/nix-installer.sh
   sh /tmp/nix-installer.sh install steam-deck --enable-flakes
   sudo steamos-readonly enable
   ```

   The install runs on Valve's Nix, not Determinate Nix: the Deck is the one machine that
   upstream Nix fits (Decisions, [Machines](decisions.md#machines)).
4. Restart the Deck:

   ```sh
   sudo reboot
   ```

5. Check that it answers:

   ```sh
   nix run nixpkgs#hello
   ```

## Apply

1. Apply. The first apply builds every package that is not in the cache already, so it takes a
   while, and `home-manager` has to bootstrap itself: until its CLI is on `PATH`, reach it
   with `nix run`, and give every conflicting file a backup with `-b backup`.

   ```sh
   nix run github:nix-community/home-manager/release-26.05 -- switch \
     --flake github:joshuadavidthomas/nix-config#deck -b backup
   ```

   Then install the CLI once, and later applies are the plain command:

   ```sh
   nix profile install nixpkgs#home-manager
   home-manager switch --flake github:joshuadavidthomas/nix-config#deck
   ```

2. Apply again after a change you want on it, as on any machine: the latest `main`, one
   command. What runs on the Deck is always a commit, as on the others.
3. `home-manager switch` writes user files that SteamOS update images own with a `.bak`
   next to them. When a SteamOS update put an image version of one of those files back,
   the `.bak` is the rollback.

The login shell stays `bash`: fish starts by typing `fish`. Do **not** run `chsh`: a SteamOS
update resets `/etc/shells`, and a login shell that is not in it keeps both the desktop
and SSH from logging in at all
([SteamOS issue #2922](https://github.com/ValveSoftware/SteamOS/issues/2922)).

Two things are not set up yet, on purpose (roadmap, Stage 2):

- **atuin is logged out.** opnix reads its secrets on the machines NixOS and macOS configure;
  the Deck has neither yet. The apply passes and mentions it.
- **commits do not sign.** The lab boxes share a signing key that opnix writes; the Deck gets
  that in Stage 2 too. Until then, sign nothing from it.

## After a SteamOS update

The store in `/home/nix` survives, home-manager's profile survives, and the home files ride on
the Deck's own storage. An update replaces the rest of the root, including `/etc`:

| What you see | Why | What to do |
| --- | --- | --- |
| `nix` no longer builds, or a setting it had is gone | The update dropped the files in `/etc` that the installer had written, the ones its keep-list entry covers | Run the installer step again. It overwrites the same files, in the same places. |
| A dotfile went back to its image version | The update image writes its own versions of a few files in the home | The `.bak` next to it, from the `backupFileExtension` rule. |
| The desktop session or SSH will not log in, `pam_shells` in the journal | The update reset `/etc/shells` and the login shell is not in it | This should stay impossible by rule: the Deck keeps bash. It has happened when a deck had `chsh` run on it; the recovery is the boot menu's "previous SteamOS" and then the shell back to `/bin/bash`. |

One more Valve bug can hang an update itself:
[issue #2957](https://github.com/ValveSoftware/SteamOS/issues/2957), open as of 2026-11. The
update stops at about 95%: its keep-list pass over `/etc/atomic-update.conf.d/` blocks on the
`/var` it has just frozen, and it can happen with any keep-list entry at all — Nix writes one
for you in the install step. Do not power the Deck off when this happens; let the update sit.
Then, from a second local shell or console:

```sh
sudo fsfreeze --unfreeze /var
```

The pass it unfreezes ends, often failing; that is the known noise, and whatever it says, the
same update started again goes through. A new SSH login is not reliable while this is going
on, which is why the recovery console needs the `deck` password and the docked keyboard.

