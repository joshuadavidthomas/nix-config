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
that coordinator. Until a box has moved, apply to it only with these steps: a plain
`colmena apply` leaves its yonderd restarting with `start it once with -leave-fabric`.

Two things change in the same restart of yonderd:

- **The binary and its flags.** The new yonderd has no `-join`, and the old one has no
  `-coordinator-url`. So the box must run the new yonderd when the new configuration is
  applied. Remove the binaries in `/var/lib/yonder/bin` first, so that the box runs the
  version pinned in `flake.lock`.
- **The membership.** Each box stored its membership of the old fabric, and the new yonderd
  does not start with it: "start it once with -leave-fabric". `-leave-fabric` forgets the
  membership when yonderd starts. Then the box joins the coordinator at `coordinatorUrl`, with
  the names of its machines and volumes. Use the flag for one apply only: with the flag,
  yonderd leaves the fabric and joins it again every time it starts.

VMs keep running when yonderd restarts: each VM is its own systemd unit.

1. Check that `coordinator.env` is on each box. Each line prints `ok`:

   ```sh
   for b in lab-1 lab-2 lab-3; do ssh $b sudo test -s /etc/yonder/coordinator.env && echo "$b ok"; done
   ```

2. Pull this repo. `flake.lock` pins the yonder that has the coordinator:

   ```sh
   git pull
   nix flake check
   ```

3. In `hosts/lab-1/default.nix`, `hosts/lab-2/default.nix` and `hosts/lab-3/default.nix`,
   add this line. Do not commit it. Nix sees the change because the files are tracked.

   ```nix
   services.yonder.extraFlags = [ "-leave-fabric" ];
   ```

4. Remove the deployed binaries from `lab-1`. yonderd keeps running until the apply:

   ```sh
   ssh lab-1 sudo rm -f /var/lib/yonder/bin/yonderd /var/lib/yonder/bin/yonder
   ```

5. Apply:

   ```sh
   colmena apply --on lab-1
   ```

6. Check that `lab-1` left the old fabric and joined the new one. The journal shows `leaving
   the fabric, as -leave-fabric asks`, then `joined the fabric` with
   `coordinator=https://yonder.joshthomas.dev`:

   ```sh
   ssh lab-1 sudo journalctl -u yonderd --since -10min | grep -E 'leaving the fabric|joined the fabric|error'
   ssh lab-1 sudo yonder status
   ```

7. Do steps 4 to 6 for `lab-2` and `lab-3`.
8. Remove the `extraFlags` lines from step 3, and apply again:

   ```sh
   git checkout hosts/lab-1/default.nix hosts/lab-2/default.nix hosts/lab-3/default.nix
   colmena apply
   ```

   yonderd restarts without the flag. It stays a member: its membership now names the new
   coordinator. Check that no box has the flag. Each line prints `0`:

   ```sh
   for b in lab-1 lab-2 lab-3; do ssh $b systemctl show yonderd -p ExecStart | grep -c leave-fabric; done
   ```

To ship yonder work in progress to a box again afterwards, use `deploy.sh` as before.

There is no way back to the Fly coordinator. If a box cannot reach the new coordinator after
it left the old fabric, yonderd stops and systemd starts it again every second. It tries to
join each time, with or without the flag. Look for the reason in
`journalctl -u yonderd`, and check `coordinator.env`.

## If it stops

| What you see in `journalctl -u yonderd` | Cause | Action |
| --- | --- | --- |
| `start it once with -leave-fabric` | The box's membership names the Fly coordinator | Steps 3 to 6 of [Move to the Cloudflare coordinator](#move-to-the-cloudflare-coordinator) |
| `flag provided but not defined: -join` | The new yonderd with the old configuration | Apply this repo's configuration |
| `flag provided but not defined: -coordinator-url` | The old yonderd with the new configuration: old binaries in `/var/lib/yonder/bin`, or `flake.lock` before the coordinator | Step 4, or step 2 |
| `Failed to load environment files` (systemd) | No `/etc/yonder/coordinator.env` | [The files on each box](#the-files-on-each-box) |
