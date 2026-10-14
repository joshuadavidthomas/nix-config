# Decisions

The owner made these decisions. Each one has its reason. Progress on them is in the
[roadmap](roadmap.md).

## Machines

- **One user, `josh`, on every machine.** The lab boxes add `orb`, for Amp orbs.
- **Amp orbs log in to the lab boxes as `orb`, not `root` or `josh`.** `orb` has passwordless
  sudo, like `josh`.
  Reason: the risk is an agent's mistake, not an attacker. A separate user keeps agents out of
  `josh`'s keys and home, and makes root a deliberate step that the journal records. Isolating
  the lab from the rest of the LAN is the network's job (VLANs), not the boxes'.
- **Every machine gets the same home.** `home/` gives the Mac, WSL, the lab boxes and VMs the
  same shells, tools, languages and coding agents. Only what a platform cannot have is
  different: Mac apps, WSL interop, server services. These go in `hosts/<name>/`.
  Reason: the same environment on every machine is the purpose of this repo.
- **The Mac keeps its sudo password.** Agents edit and build the Mac configuration; the owner
  runs `rebuild`. WSL and the lab boxes have passwordless sudo.
  Reason: the Mac mini has no Touch ID, and passwordless sudo would let any agent on the Mac be
  root. A sudo rule for `rebuild` alone does not help: an agent that applies the
  configuration can put root access in it.
- **The lab boxes are general servers.** They run Nix builds, GitHub runners, remote agents in
  their own worktrees, VMs and self-hosted services. They are not minimal servers.
- **Later, microvms can take agent and development work off the lab boxes.** Then a lab box can
  get less of `home/`, and the VMs get all of it.
- **Shared modules decide how; each host decides what.** A module in `modules/` gives every
  machine that imports it the same way of doing something, with defaults. A host changes a
  default in `hosts/<name>/` only for a fact about that machine, such as its disk or its root
  filesystem.
  Reason: the machines stay alike, and what differs is in one place per machine.
- **The lab boxes swap to zram, compressed in memory, not to disk.**
  Reason: without swap, a box that runs out of memory kills a process, such as a VM or
  yonderd. zram needs no partition, so the installed boxes get it without a reinstall.
- **A lab box's root is ext4, unless its host chooses another filesystem.** A box moves to
  another filesystem, for example XFS for yonder's reflink clones, only when it is installed
  again, one box at a time.
  Reason: the format applies only at install. One setting for all boxes would stop every box
  that was not installed again from starting. yonder works on any filesystem; XFS only makes
  its creates faster.

## Network

- **The lab is a trusted network behind Tailscale.** The lab boxes are not open to the
  internet. Where simple and hardened conflict, choose simple.
- **A new lab box joins Tailscale by itself, with the tag `lab`.** It uses the secret of a
  Tailscale OAuth client, from 1Password.
  Reason: no lab box is set up by hand. An auth key expires after 90 days at most; the client
  secret does not. A tagged node's key does not expire.

## Monitoring

Design: [Homelab monitoring](research/homelab-monitoring.md).

- **The monitoring machine on Fly joins the tailnet.** The lab boxes send to it over
  Tailscale, and Grafana is reached over Tailscale.
  Reason: the lab is a trusted network behind Tailscale. VictoriaMetrics and VictoriaLogs have
  no per-client auth, and a public endpoint would need a token on each lab box.
- **The monitor has its own tag, `tag:monitor`, and no public IP.** The tailnet policy lets
  lab boxes reach it on ports 8428 and 9428 only.
  Reason: lab boxes may not open connections on the tailnet. `tag:lab` would also give the
  monitor what lab boxes get: SSH from orbs and approved subnet routes.
- **The monitor is a multi-container Fly machine, deployed with `fly machine run
  --machine-config`.** Each service runs from its publisher's image. The files are in
  `monitor/` in this repo.
  Reason: the services are the usual Docker Compose stack, so there is no image to build and
  no process supervisor to keep. The Vector configuration, the alert rules and the dashboards
  depend on each other, so they change in one pull request.
- **Metrics are kept 1 year and logs 30 days, on the machine's volume. Backups go to R2
  each night.**
  Reason: neither VictoriaMetrics nor VictoriaLogs reads data from object storage, and at
  homelab volume a 10 GB volume holds years. History in R2 that is queried when needed is the
  Basin lake's job.
- **Alerts go to hark, and only alerts that need you soon. No Discord.**
  Reason: an alert that is not read, or that is so frequent it gets ignored, does nothing, and
  a Discord channel would not be read. The record of past alerts is in Grafana. Discord was
  set up first only because Alertmanager supports it natively; that was not a choice. A relay
  on the monitor rewrites Alertmanager's messages into hark's JSON.
- **No UPS.** The old one died, so nothing runs NUT.

## Secrets

- **1Password is the only source of secrets, on every machine.** sops goes away.
  Reason: the secrets are already in 1Password. sops only added a second system.
- **opnix reads the secrets, with a 1Password service account, on every machine.** The Mac uses
  the same service account as the other machines, not the 1Password app integration. The
  service account token is the only secret that a machine gets from outside opnix: `rebuild`
  copies it from 1Password on the Mac and WSL, and colmena copies the Mac's token to the lab
  boxes. Your user on the Mac can read the token, so agents on the Mac can read the vault.
- **Start with one shared vault, `dotfiles`, that the service account reads.** Split it later
  by reader, for example a separate vault for agents in sandboxed VMs.
  Reason: a service account cannot get access to more vaults after it is created. New items in
  a vault that it can already read need no change.
- **The account is 1Password Families.** Service accounts have a limit of 1,000 requests a day
  for the whole account. Check the use with `op service-account ratelimit`. If the limit is a
  problem, add 1Password Connect support to opnix in a fork. An overlay cannot change opnix,
  because its modules build their own package. A Connect server must run outside the lab and
  be reachable over Tailscale.
- **No SSH agent forwarding to the lab boxes.**
  Reason: agents on the boxes must work when the Mac is not connected.

## Git signing

- **All commits are signed.** The Mac and WSL sign with the 1Password key, through 1Password's
  signer.
- **The lab boxes share one signing key.** The key is kept in 1Password and registered on
  GitHub as a signing key. Agents commit as the owner; they do not have a separate identity.
  Reason: the owner's own key stays in 1Password, and there is one key to manage.

## Updates

- **Homebrew installs and updates itself.** Its own installer installs `brew` (bootstrap.sh),
  and `brew update` keeps it current. Nix only declares the formulae and casks.
  Reason: Homebrew releases about twice a week. Pinned in the flake, it had to be bumped by hand.
- **Tools that release faster than nixpkgs update themselves.** The coding agents and cf are
  installed with their own installers or npm, not packaged in Nix.
- **topgrade updates what Nix does not pin. Run it by hand about once a week, after the Nix
  update.** Steps are in [Update everything](changes.md#update-everything).
  Reason: the Mac keeps its sudo password, so a scheduled run cannot finish. A run by hand
  also shows what changed, when a beta tool breaks.
- **topgrade does not run its `system` step on NixOS.**
  Reason: that step runs `nixos-rebuild` without `--flake`, which builds `/etc/nixos`, not
  this repo.

## Project environments

- **direnv, with nix-direnv, loads project environments.** The mise `layouts` plugin from the old
  dotfiles is not used.

## Not decided

- The repo structure: layers, as now, or one file per feature, as in
  [Goxore/nixconf](https://github.com/Goxore/nixconf). Decide when the lab boxes get roles.
- The VM tool: microvm.nix, libvirt or incus.
- How remote agents are started and controlled.
