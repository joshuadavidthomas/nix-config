# yonder on the lab boxes

Each lab box runs yonderd, the daemon of [yonder](https://github.com/joshuadavidthomas/yonder.dev),
from yonder's NixOS module (`hosts/lab-1`). With `services.yonder.localBinaries`, a box runs
the yonderd that yonder's `tests/lab/deploy.sh` put in `/var/lib/yonder-bin`, and the version
pinned in `flake.lock` when nothing is there. Before yonder's module made its state directory
root's alone, that directory was `/var/lib/yonder/bin`; nothing reads it now.

The `.internal` resolver is not in yonderd. It runs in its own units from the same module:
systemd listens on `10.86.0.53:53`, UDP and TCP, in `yonder-resolver.socket`, and passes the
sockets to `yonder-resolver.service`, which runs as the system user `yonder-resolver`, with no
capabilities and no network of its own. It reads only the names file that yonderd writes in
`/run/yonder/resolver`. yonderd runs with `-resolver-listen none -resolver-group
yonder-resolver`, flags that an older yonderd does not have, so the module and the package
come from the same yonder commit: one bump of the `yonder` input moves both.

Guests' calls to their host are not in yonderd either. `yonder-connect.service`, from the
same module, runs `yonderd connect` as the system user `yonder-connect`, with no capabilities
and no address of a box, a guest, the tailnet or the LAN. It dials yonderd's control socket in
`/run/yonder/connect`, and yonderd runs with `-connect-group yonder-connect`. A yonderd in
`/var/lib/yonder-bin` older than that flag stops yonderd from starting (see
[If it stops](#if-it-stops)).

Each box sets `services.yonder.cpuOvercommit = 2`: its machines may reserve two vCPUs per
host CPU (lab-1 24, lab-2 and lab-3 16 each). Memory and disk are never overcommitted, so
memory is what fills a box first. Before 2026-10-27 the ratio was 1, and the three boxes fit
four 4-vCPU orbs in all.

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

The boxes moved to it from yonder's old coordinator, a Fly Machine on the tailnet, on
2026-10-16, with a one-time script (`scripts/yonder-move.sh`, removed afterwards; it is in
the git history).

## The CLI on the Mac

The Mac gets the `yonder` CLI from the same pinned input as the boxes (`hosts/mac/home.nix`),
so `rebuild` after a bump of `yonder` moves it too. To work the whole fabric, it reads the
coordinator from `~/.config/yonder/config`, mode 0600, placed by hand like the boxes' files:

```sh
YONDER_COORDINATOR_URL=https://yonder.joshthomas.dev
YONDER_COORDINATOR_TOKEN=...
YONDER_ACCESS_CLIENT_ID=...
YONDER_ACCESS_CLIENT_SECRET=...
```

Without it, `yonder -ssh lab-1 machine list` works one box over SSH, through the box's socket.
That needs `josh` in the box's `yonder` group, which nix-config does not add.

## Moving a box to the resolver's own units (once)

yonder's `tests/lab/resolver-unit.sh` ran the resolver's units on each box before nix-config
took them: copies under `/run/systemd/system`, which hide the module's units in `/etc`, and a
drop-in `/run/systemd/system/yonderd.service.d/resolver.conf` that gives yonderd the
resolver's flags. Until then yonderd ran from `/var/lib/yonder/bin`, where `deploy.sh` put
it, and the script's copy in `/var/lib/yonder-bin` ran only the resolver. After the move the
module's wrapper runs that copy, which may be older than the box's `host.db`. So remove the
copy too, and the box runs the pinned package. The `yonder-resolver` user and group that the
script made with `useradd` stay: NixOS's user activation keeps an existing user's UID and
group's GID, and sets the declared home and shell.

One box at a time, from the Mac:

```sh
ssh lab-1 'sudo yonder status'   # build and executable, to compare after
ssh lab-1 'sudo systemctl stop yonder-resolver.socket yonder-resolver.service; sudo rm -f /run/systemd/system/yonder-resolver.socket /run/systemd/system/yonder-resolver.service /run/systemd/system/yonderd.service.d/resolver.conf /var/lib/yonder-bin/yonderd /var/lib/yonder-bin/yonder; sudo systemctl daemon-reload'
colmena apply --on lab-1
```

`.internal` does not answer on the box between the last two. yonderd keeps running; if it
restarts before the apply, it runs from `/var/lib/yonder/bin` with the resolver inside it,
so keep that directory until the box has moved. Then on the box:

- `sudo yonder status`: up, with the pinned build, from `/nix/store`
- `systemctl status yonder-resolver.socket`: active (listening), on `10.86.0.53:53`, datagram
  and stream, loaded from `/etc/systemd/system`
- `getent hosts db.internal`: an address

Then `sudo rm -rf /var/lib/yonder/bin`, which nothing reads now.

## If it stops

| What you see in `journalctl -u yonderd` | Cause | Action |
| --- | --- | --- |
| `Failed to load environment files` (systemd) | No `/etc/yonder/coordinator.env` | [The files on each box](#the-files-on-each-box) |
| `flag provided but not defined: -coordinator-url`, `-resolver-listen` or `-connect-group` | `deploy.sh` put a yonderd older than the module in `/var/lib/yonder-bin` | Ship a newer one with yonder's `deploy.sh`, or go back to the pinned one with `deploy.sh revert` |

| What you see | Cause | Action |
| --- | --- | --- |
| `getent hosts <name>.internal` finds nothing, and `systemctl status yonder-resolver.socket` is not `active (listening)` | The socket is stopped, or units under `/run/systemd/system` hide the module's (yonder's `tests/lab/resolver-unit.sh` puts them there) | `systemctl cat yonder-resolver.socket` shows which file is loaded. Remove the ones under `/run` (`resolver-unit.sh revert`), then `systemctl start yonder-resolver.socket` |
