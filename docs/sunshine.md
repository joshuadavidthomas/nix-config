# Sunshine on the Steam Deck

The Deck streams its screen to Moonlight clients. Today that is `decky-sunshine`: a Decky
Loader plugin that starts the Flathub Sunshine as a system Flatpak, as root, through a setuid
copy of `bwrap` that the plugin itself installs and owns (probed 2026-11-09). It works, and it
is outside the repo entirely: the autostart is plugin state, the host's config belongs to root
inside the sandbox, and the plugin leaves the web UI's Basic-auth credential in plain JSON,
world-readable in a home directory on a tailnet node
(`/home/deck/homebrew/settings/decky-sunshine/decky-sunshine.json`).

This doc moves Sunshine to the repo, the same way every other Deck service got there
([Set up the Steam Deck](new-deck.md)): the binary from the pinned nixpkgs, the config in the
home, one keep-listed unit from steamos-etc, and the credentials in 1Password. When it works in
both sessions, the plugin and the Flatpak it launched go away.

The Deck's other Flatpaks (the games and launchers) are a separate question, not this one:
[roadmap](roadmap.md#steam-deck).

## The shape

One piece per layer, all of them things the repo already does elsewhere:

- **The binary** comes from nixpkgs. The repo's locked `nixos-26.05` carries Sunshine
  2026.914.233613, ahead of the 2026.516 Flatpak now running. It goes through
  `home.packages` in `hosts/deck/default.nix`, so a SteamOS update preserves it exactly as it
  preserves the Nix store.
- **The config** goes in the home: `~/.config/sunshine/`. Declaratively, but **only after the
  first run**: Sunshine writes its own settings from its web UI into `sunshine.conf` and its
  state into `sunshine_state.json`, so a store-linked config must not exist before the defaults
  are known. Declare the minimum that survives a deck wipe — capture settings, port answer —
  and nothing the web UI needs to write into.
- **The launch** is a `steamos-etc.services` unit, the `rex-login-server` shape: an attrset key
  `deck-sunshine` in `hosts/deck/default.nix`, so it lands in `/etc/systemd/system` and rides
  the keep-list through Valve's updates. It runs as `deck` first. The Flatpak today runs as
  root, and whether Game Mode capture accepts a user process is the open test below; if it
  does not, the unit flips to root with
  `Environment = [ "XDG_CONFIG_HOME=/home/deck/.config" ]`, which keeps the config and the
  credentials in the home either way.
- **The credentials** follow [Decisions](decisions.md#secrets): a 1Password item
  `op://dotfiles/Sunshine deck/password`, read with the opnix module the Deck already imports.
  The first run provisions Sunshine with it, and Sunshine's own state file in the home holds
  the result — the same pattern as the atuin login, and it removes the JSON the plugin keeps
  today.

The unit lives in `hosts/deck/default.nix`, in the `rex-login-server` shape, built from two
helpers that run as `deck`. The name discovery is where the plan changed against its first
guess (probed 2026-11-09): the Game Mode session has **no `wayland-*` socket at all** — its
compositor socket is `gamescope-0`, and Plasma's is `wayland-0`. So:

- `deck-sunshine-wait` runs as `ExecStartPre`: a 60-second loop over
  `wayland-*` and `gamescope-0` sockets in deck's runtime dir; a boot with no session fails it
  and the unit's own `Restart=on-failure` picks it up until the first session opens. The
  plugin's guard was `drm_info -j` (a connected screen); this waits one step further, for the
  screen a capture can hold.
- `deck-sunshine-launch` exports `WAYLAND_DISPLAY` from whichever socket exists (wayland-*
  preferred, so a switch-over home lands on the live Plasma), plus the runtime dir and the
  session bus, which a system unit does not inherit on its own.

One thing stayed open until the first apply, and it is now a finding: **Sunshine's Wayland
capture is KMS over `/dev/dri`, which wants `CAP_SYS_ADMIN`.** The first apply (2026-11-09)
brought the ports up with the web UI answering and then failed to find any encoder —
`Encoder [vaapi] failed … Failed to gain CAP_SYS_ADMIN`, the precise line the tests were
looking for, and the reason the plugin ran everything as root. The unit answers with
`AmbientCapabilities = [ "CAP_SYS_ADMIN" ]`: the capability rides the exec, Sunshine sets up
capture, and its own `drop_elevated_privileges` lets go afterwards. Narrower than the root
fallback this doc carried until then.

The second apply brought the encoder stack's own finding, and it is not Sunshine's: with
capture working, `Encoder [vaapi]` still failed, next to `MESA-LOADER: failed to open
/run/opengl-driver/lib/gbm/dri_gbm.so` — no GBM device at all. That is the generic gate for
every Nix-built GL/Vulkan program on a foreign OS, not something Sunshine-shaped: Nixpkgs
injects `/run/opengl-driver` into its search paths, and a SteamOS machine does not have it.

Home Manager owns this since 25.11 (`targets.genericLinux` builds the GPU-drivers derivation
and, at every apply, checks it against `/run/opengl-driver`), and the pinned steamos-etc module
owns the arrangement better than its own sudo command does:
`programs.steamos-etc.gpuDrivers = true` writes `/etc/tmpfiles.d/non-nixos-gpu.conf` from
`${config.targets.genericLinux.gpu.drivers}` — derived at every apply, so a nixpkgs bump
carries the right frame — keeps it through SteamOS updates, and creates the link at every boot
even while `/nix` is not yet mounted. HM's absorbed check gets a `mkForce` empty, so the
applies stop asking for `non-nixos-gpu-setup` forever. The sudo setup that proved this out ran
once, on 2026-11-09, and the Vulkan H.264 and HEVC encoders of the Deck's VCN answered on the
same start that found the GBM device.

Both helpers are store paths the unit file names — they persist through Valve's updates exactly
like the Rex unit's binary path already does. The key stays snake-case like the other
steamos-etc units, because the keep-list names it.

## What the plugin death costs, and what replaces it

- **Start/stop and the pairing QR from the Game Mode quick settings** go away. A service is the
  answer to the first. For pairing, the client opens Sunshine's own web UI instead
  (`https://steamdeck.<tailnet>:47990`, or `https://<deck-lan-ip>:47990` on the LAN) — username,
  password from 1Password, then the client's PIN in, same pairing act, one screen dumb-er.
- **The autostart state moves from plugin JSON to the unit** and gains what the plugin's
  heuristics approximated: systemd's own wait, restart, and to-log discipline
  (`journalctl -u deck-sunshine`).
- **The world-readable credential file** gets removed outright with the plugin; the new
  password is provisioned once from the GUI-less path (below) and lands in Sunshine's own
  state file, mode 0600 in a 0700 directory.

## Provision

1. Create the 1Password item `Sunshine deck` (vault `dotfiles`), password field. Generate the
   password there; the same item serves the web UI login on any client.
2. Add the secret to `programs.onepassword-secrets.secrets`, the way atuin's three entries
   work in `hosts/deck/default.nix` (path `.config/opnix/sunshinePassword`, group `deck`).
3. Once, over SSH after an apply that has the secret, provision and confirm:

   ```sh
   sunshine --creds sunshine "$(op read 'op://dotfiles/Sunshine deck/password')"
   systemctl restart deck-sunshine
   systemctl is-active deck-sunshine
   ```

## The tests, in order

The two questions this plan does not pre-answer — what Game Mode capture needs, and whether
`/dev/uinput` is reachable without device groups — are both settled by the same sequence:

1. **Device access — confirmed, 2026-11-09, on this image.** `deck` is in no `video` or
   `input` group, and it does not matter: `/dev/dri/card0` and `/dev/uinput` both carry
   `user:deck:rw-` ACLs, the mechanism the Flatpak version already rides on. What is left is
   the watch item, not the test: the ACL source is SteamOS's own, and an update could change
   it — if Game Mode capture ever loses device access, check `getfacl` before blaming
   Sunshine.
2. **Desktop Mode first**, with the apply done: start the unit, point Moonlight at the deck,
   pair through the web UI, stream the desktop. This alone proves the package, the config
   paths, the service, and user-mode capture on Plasma — the battle-tested path upstream.

   ```sh
   systemctl status deck-sunshine
   journalctl -u deck-sunshine -n 50
   ```

3. **Then Game Mode**, the thing the plugin existed for: switch to Game Mode, confirm the unit
   survived the session switch, and stream from Moonlight.

   ```sh
   systemctl is-active deck-sunshine
   ```

   If Game Mode capture shows a black screen or no display: Sunshine's capture backend is the
   lever, set in `~/.config/sunshine/sunshine.conf` (`capture = wayland` for Desktop, and
   Game Mode wants whatever the journal names as its accepted grabber). Game Mode is also the
   only place the root fallback earns its keep. Write down which capture value wins both
   sessions in this doc's place, before the config gets declared.
4. **Over the tailnet**: both sessions again via `steamdeck.<tailnet>`, since Moonlight will
   spend most of its life there. The ports (47984–47990 TCP, 47998–48000 TCP+UDP) are
   node-wide on the tailnet already, so this is a connectivity test, not a config one.
5. **A cold reboot**: the roadmap's open "units come up with no session" test doubles as
   Sunshine's: after boot with no login, the unit should be in its 60-second
   `ExecStartPre` wait, then fail after timeout until the first session opens — that is
   correct behavior for a display-less boot, and it is the cold-reboot record this doc makes.
6. **The Moonlight client itself** lands on the Mac in the same repo change if not installed:
   add `moonlight` to `hosts/mac/default.nix`'s `casks`, in the same commit, so the client is
   one `rebuild` away on whatever machine tests it.

## Apply

One prerequisite the plan missed on the first write, and the ports explain: the plugin's
Sunshine is running right now and holds the ports (47984–47990), so it and the new unit cannot
run at the same time. Stop the old one first — the Game Mode quick settings, Plugin menu,
Decky Sunshine's stop switch does it — then apply:

From [Set up the Steam Deck](new-deck.md#stage-2-secrets-rex-and-the-keep-list), unchanged:

```sh
home-manager switch --refresh --flake github:joshuadavidthomas/nix-config#deck
ssh -t deck 'sudo /home/deck/.nix-profile/bin/steamos-etc'
```

The second command is what puts `deck-sunshine` in `/etc` and the keep-list, and starts it.
`nix flake check` runs on the Mac before either, as on every change.

## Retire the plugin and the Flatpak

Only once Game Mode streams. From the Deck's console (dock keyboard; SteamOS needs its sudo
password here, not the tailnet SSH session):

1. Delete the plugin with the pieces that belong to it — plugins, the setuid `bwrap`, and the
   JSON that holds the old password:

   ```sh
   sudo rm -rf /home/deck/homebrew/plugins/decky-sunshine
   sudo rm -rf /home/deck/homebrew/data/decky-sunshine
   sudo rm -rf /home/deck/homebrew/settings/decky-sunshine
   sudo rm -rf /home/deck/homebrew/logs/decky-sunshine
   ```

   `decky-autoflatpaks` is not touched by any of this: it updates Flatpaks that exist, it
   installs none.
2. Take the Flatpak down, system scope:

   ```sh
   sudo flatpak uninstall --system dev.lizardbyte.app.Sunshine
   sudo flatpak uninstall --system --unused   # drop the runtime no other app needs
   ```

   `--unused` names what is gone before it goes (read the list; stop at one the other 26
   Flatpaks still use).
3. Roll back just as simply: reinstall the plugin through Decky's app store (it pulls the
   Flatpak back in), stop and remove the unit (`steamos-etc` drops the keep-list entry when the
   config does), apply, done. Neither side is tangled into the other, because neither side is
   a Flatpak anymore.

## The record

`docs/decisions.md` gains its entry with the implementation, not before — written once Game
Mode capture exists, since the answer it records is the capture finding as much as the choice
itself. The shape, drafted here so the write-up is ready:

> **The Deck streams itself with the repo's own Sunshine.** nixpkgs' package under the home,
> its config in the home, one keep-listed unit from steamos-etc, the credential in 1Password.
> The decky-sunshine plugin and its system Flatpak are retired; nothing Sunshine-shaped runs as
> root unless capture says it must, and if it must, its config still lives in the home.
> Reason: the plugin's arrangement left a Basic-auth credential world-readable on a tailnet
> node and a setuid `bwrap` the repo does not own, and nothing about it was recorded. The
> repo already owned every other Deck service; nixpkgs' Sunshine was a year-fresher than the
> Flatpak it replaces; boot-time wait and restart move from plugin heuristics to systemd.

After the retirement, [Set up the Steam Deck](new-deck.md) gains the Sunshine line in its
stage list, and [the roadmap](roadmap.md#steam-deck) checks its boxes.
