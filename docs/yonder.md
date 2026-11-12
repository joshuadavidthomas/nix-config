# yonder on the lab boxes

Each lab box runs yonderd, the daemon of [yonder](https://github.com/joshuadavidthomas/yonder.dev),
from yonder's NixOS module (`hosts/lab-1`). With `services.yonder.localBinaries`, a box runs
the yonderd that yonder's `tests/lab/deploy.sh` put in `/var/lib/yonder-bin`, and the version
pinned in `flake.lock` when nothing is there. Before yonder's module made its state directory
root's alone, that directory was `/var/lib/yonder/bin`; nothing reads it now.

The `.internal` resolver is not in yonderd. It runs in its own units from the same module:
systemd listens on `10.86.0.53:53`, UDP and TCP, in `yonder-resolver.socket`, and passes the
sockets to `yonder-resolver.service`, which runs as the system user `yonder-resolver`, with no
capabilities. It reads only the names file that yonderd writes in `/run/yonder/resolver`. A
guest's query for a name outside `.internal` it forwards to 1.1.1.1, then 9.9.9.9 (the module's
`services.yonder.dns`), the only addresses its unit may send to; the host and tailnet devices
are refused such names. Before 2026-10-27 it refused them for guests too, and pnpm 12, which does
not move on to the guest's next server, could not install anything in an orb. yonderd runs with `-resolver-listen none -resolver-group
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

All three boxes serve their machines' disks from the block store (`services.yonder.servedDir
= "/var/lib/yonder-served"`), lab-2 and lab-3 from 2026-11-05 and lab-1 from 2026-11-06: a new machine's disk is an E2B-format disk the
box reads over NBD from R2 through URLs the coordinator signs, and a pause publishes it as a
checkpoint instead of exporting a gzip. The module loads `nbd` with `nbds_max=0 max_part=0`
and adds udev rules that keep the host's own storage stack off the NBD devices. A machine made
on loop disks before the switch keeps them.

The 2026-11-07 pin supports live checkpoints. A plain checkpoint freezes the guest
filesystem, cuts its disk and thaws it before upload. An Amp pause freezes the filesystem,
pauses Firecracker, stores the cut and stops the VM without resuming it. Resume can restore
the disk on another host, but does not preserve memory or processes. A guest without a
working freeze listener takes the existing stop/checkpoint fallback during Amp pause.

The block worker keeps Objects read-only. It exports a publication into its private queue,
and the host checks and uploads those bytes. Only bounded, root-owned metadata enters
Objects. Admission reserves the worst-case staging space and 132 MiB of host metadata,
so a 20 GiB served disk charges 41 GiB. Older, smaller queue files are refused rather than
silently resized. Daemon recovery counts allocated served queues as yonder's reserved space,
so their allocation is not charged twice after a restart.

All three lab hosts applied this pin on 2026-11-07, one at a time, lab-3 first.
Their daemon, connector and resolver run from the pinned Nix package, and
`/var/lib/yonder/platform` points directly to the pinned platform in `/nix/store`.
The temporary `/var/lib/yonder-bin` binaries and platform-link overrides are gone.
Canary VMs survived the service restarts, and fresh VMs booted with the guest freeze
service active. The production coordinator was already on the verified build and was
not redeployed during this rollout.

The 2026-11-08 pin (a35357d) runs each VM's Firecracker under AWS's jailer, in a network
namespace of its own. The module's `services.yonder.firecracker` is now AWS's static
Firecracker 1.16.2 with `jailer` beside it, which fixes CVE-2026-122192. yonderd refuses to
start with a dynamically linked Firecracker or one without a jailer next to it, so nix-config
must not set that option to nixpkgs' `firecracker`. A rebuild restarts only yonderd: a running
VM keeps its old unit until it next starts. lab-3 ran a wrapper from `/var/lib/yonder-bin` for a
while; it was removed before the 4a655a2 pin, and no box runs anything from there.

The 2026-11-10 pin (5c27e42) gives every machine a local root disk: the guest writes to
dm-era over dm-clone over files in its machine's directory, and the NBD worker only serves the
image's or checkpoint's base for blocks not yet copied. The served directory is no longer
optional (`services.yonder.servedDir` defaults to `/var/lib/yonder-served`), and the module puts
lvm2's `dmsetup` and thin-provisioning-tools' `era_invalidate` on yonderd's PATH. It adds
`yonder-clean`, a oneshot unit whose stop runs `yonderd close-disks` at shutdown, so a clean
reboot keeps every write; after an unclean one a root disk rolls back to its last checkpoint,
and volumes are the durable storage. This build applies host database migrations 0017 and
0018, which older builds refuse, so going back past it needs the database from before.

The 2026-11-10 pin (4a655a2) closes yonder's local write path milestone on the same module and
schema (no new migration, so going back to 5c27e42 is safe). A storage stop now disconnects a
dead worker's export before it kills the VM, clone regions are 4 KiB, a close whose flush of the
era device fails puts the disk back to its last checkpoint, and `machine inspect` says a write
did not reach the disk rather than an unclean host boot. lab-3's `/var/lib/yonder-bin` was
emptied before this pin's rebuild, so its wrapper runs the pinned package like the other boxes.

From 2026-11-11 the input names a release tag, not a branch: `yonder.url =
"github:joshuadavidthomas/yonder.dev/v0.1.0-rc1"`, yonder's first cut release
(`wiki/designs/releases.md`). The lab runs only cut releases; a new one moves the tag in
`flake.nix` and `nix flake update yonder` locks its commit (e62d44a for v0.1.0-rc1). The fetch is
the same `github` fetcher with the boxes' existing GitHub token, so a tag needs no other
credential. v0.1.0-rc1 is 4a655a2's module and schema plus the release identity: a box reports
its release, and the coordinator (deployed from the same tag on 2026-11-11) refuses a box on a
newer release than its own. The boxes moved one at a time, lab-3, lab-2, lab-1.

The pin moved to `v0.1.0-rc2` (ea18cf5) the same day, after the coordinator was deployed from
that tag with orbs on. For a box rc2 is rc1 with a new release string: yonderd, the module and
the schema are unchanged; the orb controller now calls the fleet as the operator with no orbs
token. Same fetcher, same token, same order: lab-3, lab-2, lab-1.

The pin moved to `v0.1.0-rc3` (a9c4efe) on 2026-11-11, right after the coordinator was
deployed from that tag. rc3 adds suspend with memory: a box reports `suspend=yes`, and warm
slots stay off (`slots=no`) because no box sets `-slot-cap-gib`. The host ledger gains
migrations 0019 and 0020, and rc2's yonderd refuses to start on the result, so
`nixos-rebuild switch --rollback` alone does not take a box back to rc2; yonder's
`wiki/plans/release-rc3.md` ("Backing a box out") gives the back-out.

On 2026-11-12 lab-3 alone turned warm slots on with `-slot-cap-gib 18` (Josh: "18 GiB on
lab-3"), in its `extraFlags`, for step 2's kill tests: it reports `slots=yes`, and a pause of
an orb there keeps up to 18 GiB of guest memory on its disk for a resume. lab-1 and lab-2
still set no cap and report `slots=no`.

The pin moved to `v0.1.0-rc4` (a884cc7) on 2026-11-12, right after the coordinator was
deployed from that tag. rc4 carries suspend step 2's kill-test fixes and a static modprobe on
the platform's modules drive, so each box's platform store path changes: warm slots and
in-place suspends taken on rc3 boot cold after the rebuild, and lab-3's slots are dropped when
yonderd starts. The host ledger does not migrate (it stays at version 20), so `nixos-rebuild
switch --rollback` takes a box back to rc3. lab-3 keeps `-slot-cap-gib 18`. Order: lab-3,
lab-1, lab-2 (yonder's `wiki/plans/release-rc4.md`).

From 2026-11-06 a box pulls machine images from public registries by digest (anonymous HTTPS)
and caches them under `/var/lib/yonder/images/oci`. yonderd caps that cache at 10% of the state
filesystem, and lab-2's and lab-3's are 234 GiB, so both set
`services.yonder.extraFlags = [ "-image-cache-gib" "20" ]`; lab-1 keeps the default 32 GiB.
Orbs place only on boxes labelled `disks=served` (`yonder node label <box> disks=served`):
all three, lab-1 from 2026-11-06.

The three lab boxes are members of one fabric. yonder's coordinator on Cloudflare, a Durable
Object at `https://yonder.joshthomas.dev`, coordinates it. Each box dials out to it
(`services.yonder.coordinatorUrl`).

The guest images are not in this flake. yonder's `tests/lab/deploy.sh images` builds them on
each box and links `/var/lib/yonder/images/<name>` to the build in the Nix store. Since yonder
56d42d2 a machine records the build it was made from and boots that build after its image is
rebuilt, through a link yonderd keeps in `/var/lib/yonder/images/.builds`. `deploy.sh` keeps
each build alive with its own GC root in `/nix/var/nix/gcroots/yonder-images`. Removing one
leaves the machines made from that build unable to boot.

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
ssh lab-1 rebuild
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
| `database schema version N is newer than this binary (M)` | A newer yonderd (a later pin, or `deploy.sh`) migrated `/var/lib/yonder/host.db`; host migrations only go forward | Run a yonderd at least that new: bump the pin, or ship one with `deploy.sh`. Going back to an older pin needs the database from before the migration |

| What you see | Cause | Action |
| --- | --- | --- |
| `getent hosts <name>.internal` finds nothing, and `systemctl status yonder-resolver.socket` is not `active (listening)` | The socket is stopped, or units under `/run/systemd/system` hide the module's (yonder's `tests/lab/resolver-unit.sh` puts them there) | `systemctl cat yonder-resolver.socket` shows which file is loaded. Remove the ones under `/run` (`resolver-unit.sh revert`), then `systemctl start yonder-resolver.socket` |
