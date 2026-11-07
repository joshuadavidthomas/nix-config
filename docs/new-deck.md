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

Two things need the home's secrets, which arrive at Stage 2 below: atuin's login and commits'
signing. A first Stage 1 apply logs neither, and says so.

## Stage 2: secrets, Rex and the keep-list

Stage 2 gives the Deck the secrets and the lab boxes' system services, from the home-manager
configuration plus one privileged apply. It happens in this order, once:

1. Copy the service account's token from the Mac into the Deck's home, not `/etc/opnix-token`:
   an update drops `/etc`, and the home is the Deck's own. Now the secrets arrive at each
   apply, not once:

   ```sh
   cat /etc/opnix-token | ssh deck 'umask 077; mkdir -p ~/.config/opnix && cat > ~/.config/opnix/token'
   ```

2. Write Nix's netrc for the rex flake input, from the same secret a lab box or the Mac has,
   so the apply can fetch it. After the first apply, home-manager itself rewrites it
   (hosts/deck), so this is the only time it is by hand:

   ```sh
   ssh lab-1 'sudo cat /var/lib/opnix/secrets/rexToken' \
     | ssh deck 'umask 077; printf "machine pkgs.superlogical.com login rex password %s\n" "$(cat)" > ~/.config/nix/netrc'
   ```

3. Apply. Always with `--refresh`: a branch moves, and a cached evaluation has the inputs of
   an older commit:

   ```sh
   home-manager switch --refresh --flake github:joshuadavirthomas/nix-config#deck
   ```

4. Privileged apply. `steamos-etc` writes the `/etc` files home-manager declares, carries
   them over SteamOS updates with its keep-list, and starts the units it keeps:

   ```sh
   ssh -t deck 'sudo /home/deck/.nix-profile/bin/steamos-etc'
   ```

   It runs with sudo only when something actually changed; without changes it says
   `/etc up to date`. After an apply, `steamos-etc --check` without sudo reports what still
   differs. What it manages: `/etc/rex/accounts.jsonc`, the units `rex-login-server` and
   `rex-tailscale-serve`, the every-boot lookup that keeps a SteamOS update from hanging on
   `/etc/atomic-update.conf.d`, and home-manager's `user@.service` drop-in.

5. Check. Rex's login server and the Serve mapping answer like the lab boxes:

   ```sh
   systemctl is-active rex-login-server rex-tailscale-serve
   /opt/tailscale/tailscale serve status
   curl https://steamdeck.tail014d2.ts.net:7297/   # 404 without a caller is right
   ```

   A bare GET returns 404 here, not 403: it means the caller was admitted onto the account
   server and the refusal came only from there (Rex's handshake didn't start), same as lab-1.
   A refusal at admission would show 403. If Rex ever refused a caller again, the first
   line to look for in `journalctl -u rex-login-server` is `pam` — SteamOS's modules dlopen
   libraries rex's prebuilt binary rolls without. On the deck, the unit runs `--pam=false`
   (rex's container mode, which does shadow-based account checks): without it, admission
   happened nowhere — SteamOS being Arch-family, its "other" PAM policy refuses every
   account, and the NixOS-built PAM file this repo's lab boxes carry would have to be
   SteamOS-shaped for a prebuilt binary. The deck stays on rex's simpler path; the lab
   boxes keep the module-shaped one.

The attrset keys in `programs.steamos-etc.services` name their unit files — keep the lab
boxes' snake-case shape (`rex-login-server`), which the units' `Requires` and `After` also
name.

## Staying on while docked

The Deck's job when docked is to be reachable, and the thing that undoes that is a suspend —
SteamOS's idle one, a session's, or a lid event all take the tailnet with it. The repo owns
one unit for this: `deck-always-on.service`, a logind inhibitor (`systemd-inhibit --what=sleep`)
that runs from both SteamOS binaries. While it runs, no sleep happens: CPU, Wi-Fi and
services keep running behind the screen, which still goes dark on its own timeout. The
`sshd` and `tailscaled` services were enabled once by hand and the SteamOS keep-list keeps
them across updates, so a restart brings them back by themselves.

For a deliberate suspend — say, to unplug and walk away — stop the unit first:

```sh
sudo systemctl stop deck-always-on
```

and start it again when it goes back on the dock:

```sh
sudo systemctl start deck-always-on
```

Atuin syncs from the first apply; commits sign with the lab boxes' shared key, as on a lab
box. The tailnet side itself — SteamOS's own tailscaled under `/opt/tailscale` and its
keep-listed files — stays out of this repo's hands.

## After a SteamOS update

The store in `/home/nix` survives, home-manager's profile survives, and the home files ride on
the Deck's own storage. An update replaces the rest of the root, including `/etc`:

| What you see | Why | What to do |
| --- | --- | --- |
| `nix` no longer builds, or a setting it had is gone | The update dropped the files in `/etc` that the installer had written, the ones its keep-list entry covers | Run the installer step again. It overwrites the same files, in the same places. Then the Stage 2 apply: `steamos-etc` and the switch (its order is the Stage 2 list above). |
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

