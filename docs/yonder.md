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

The boxes moved to it from yonder's old coordinator, a Fly Machine on the tailnet, on
2026-10-16, with a one-time script (`scripts/yonder-move.sh`, removed afterwards; it is in
the git history).

## If it stops

| What you see in `journalctl -u yonderd` | Cause | Action |
| --- | --- | --- |
| `Failed to load environment files` (systemd) | No `/etc/yonder/coordinator.env` | [The files on each box](#the-files-on-each-box) |
| `flag provided but not defined: -coordinator-url` | `deploy.sh` put a yonderd older than the coordinator in `/var/lib/yonder/bin` | Ship a newer one with yonder's `deploy.sh`, or go back to the pinned one with `deploy.sh revert` |
