# yonder on the lab boxes

Each lab box runs yonderd, the daemon of [yonder](https://github.com/joshuadavidthomas/yonder.dev),
from yonder's NixOS module (`hosts/lab-1`). With `services.yonder.localBinaries`, a box runs
the yonderd that yonder's `tests/lab/deploy.sh` put in `/var/lib/yonder/bin`, and the version
pinned in `flake.lock` when nothing is there.

The three lab boxes are members of one fabric. yonder's coordinator on Cloudflare, a Durable
Object at `https://yonder.joshthomas.dev`, coordinates it. Each box dials out to it
(`services.yonder.coordinatorUrl`).

## The files on each box

Two files are placed on each lab box by hand. They are not in the Nix store or in git. Each
is owned by root, mode 0600.

| File | What it holds | Who reads it |
| --- | --- | --- |
| `/etc/yonder/coordinator.env` | `YONDER_COORDINATOR_TOKEN`, and the box's own Cloudflare Access service token: `YONDER_ACCESS_CLIENT_ID` and `YONDER_ACCESS_CLIENT_SECRET` | yonderd only (`services.yonder.environmentFile`) |
| `/etc/yonder/secrets.env` | `KEY=VALUE` lines for the guests, for example `SSH_AUTHORIZED_KEY_MAC` | yonderd gives every line to every guest VM |

Keep the coordinator's tokens out of `secrets.env`: every guest would get them.

yonderd does not start without `coordinator.env`. yonder's `coordinator/alchemy.run.ts` writes
one for each box. To put it on a box:

```sh
ssh lab-2 'sudo install -d -m 0755 /etc/yonder && sudo install -m 0600 /dev/stdin /etc/yonder/coordinator.env' < lab-2.env
```

## Move to the Cloudflare coordinator

Do this once. Before it, the lab boxes are members of the fabric that `yonder-coordinator`,
a Fly Machine on the tailnet, coordinated, with `-join yonder-coordinator`. yonder has retired
that coordinator. Move each box with `scripts/yonder-move.sh`, not a plain `colmena apply`,
which leaves its yonderd restarting with `start it once with -leave-fabric`.

Two things change in the same restart of yonderd:

- **The binary and its flags.** The new yonderd has no `-join`, and the old one has no
  `-coordinator-url`. So the box must run the new yonderd when the new configuration is
  applied. Remove the binaries in `/var/lib/yonder/bin` first, so that the box runs the
  version pinned in `flake.lock`.
- **The membership.** Each box stored its membership of the old fabric, and the new yonderd
  does not start with it: "start it once with -leave-fabric". `-leave-fabric` forgets the
  membership when yonderd starts. Then the box joins the coordinator at `coordinatorUrl`, with
  the names of its machines and volumes. Use the flag for one start only: with the flag,
  yonderd leaves the fabric and joins it again every time it starts.

VMs keep running when yonderd restarts: each VM is its own systemd unit.

`scripts/yonder-move.sh` does the move, one box at a time. Run it on the Mac, in
`~/.nix-config`, on main:

```sh
git pull
scripts/yonder-move.sh            # lab-1, lab-2 and lab-3
scripts/yonder-move.sh lab-2      # one box
```

For each box, it:

1. Stops if the box has no `/etc/yonder/coordinator.env`, and skips the box if it is a
   member of the new coordinator already.
2. Removes the binaries in `/var/lib/yonder/bin`.
3. Adds `-leave-fabric` to yonderd's command with a drop-in in `/run`, which a reboot also
   removes. Nothing changes in this repo.
4. Runs `colmena apply --on <box>`. yonderd restarts with the new binary, leaves the old
   fabric and joins the new one. The script waits up to 2 minutes for `joined the fabric`.
5. Removes the drop-in and restarts yonderd without the flag. It checks that yonderd starts
   as a member and prints `yonder status`.

If a box stops halfway, the script says why and stops. Fix the cause, and run it again for
that box.

To ship yonder work in progress to a box again afterwards, use `deploy.sh` as before.

There is no way back to the Fly coordinator. If a box cannot reach the new coordinator after
it left the old fabric, yonderd stops and systemd starts it again every second. It tries to
join each time, with or without the flag. Look for the reason in
`journalctl -u yonderd`, and check `coordinator.env`.

## If it stops

| What you see in `journalctl -u yonderd` | Cause | Action |
| --- | --- | --- |
| `start it once with -leave-fabric` | The box's membership names the Fly coordinator | Run `scripts/yonder-move.sh <box>` |
| `flag provided but not defined: -join` | The new yonderd with the old configuration | Apply this repo's configuration |
| `flag provided but not defined: -coordinator-url` | The old yonderd with the new configuration: old binaries in `/var/lib/yonder/bin` | Run `scripts/yonder-move.sh <box>` |
| `Failed to load environment files` (systemd) | No `/etc/yonder/coordinator.env` | [The files on each box](#the-files-on-each-box) |
