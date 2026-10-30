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
- **The heartbeat is a Cloudflare Worker with a Durable Object.** The monitor pings it through
  the hark relay; when the pings stop for 5 minutes, it tells hark.
  Reason: it must run outside the monitor, and Cloudflare will be used anyway (the Basin lake).
  A Durable Object's alarm needs no polling, and Cloudflare retries it when hark fails.
- **What needs you even at night is a hark on-call page; the rest are silent notifications.**
  Pages: a box silent, a drive failing or warning, the monitor silent.
  Reason: hark's ordinary notifications have no sound. Its on-call pages have a sound and
  repeat until acknowledged. They are not time-sensitive on the phone: hark's iOS app lacks
  Apple's time-sensitive entitlement, so iOS treats them as ordinary. To get them through a
  Focus, allow Hark in that Focus.
- **No logs from inside yonder's VMs.** The monitor collects what the host sees of a VM (its
  unit, CPU, network), not what runs in it.
  Reason: the VMs are guests, sandboxes for agents and other workloads. What happens inside them
  is theirs, and the monitor would become a place their data ends up, kept for 30 days.
- **The heartbeat Worker's logs stay in Cloudflare (Workers Logs).**
  Reason: VictoriaLogs listens only on the tailnet, and Cloudflare isn't on it. When the Basin
  lake comes, the Worker's logs can go there with the rest.
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
  copies it from 1Password on the Mac and WSL, and nixos-anywhere copies the Mac's token to a
  lab box at install. Your user on the Mac can read the token, so agents on the Mac can read
  the vault.
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
- **Every machine distrusts the two roots behind the compromised eMudhra intermediates
  (October 2026).** The list is `security.pki.caCertificateBlacklist` in
  `modules/nixos/default.nix` and `modules/darwin/default.nix`. Remove both once
  `nix eval .#nixosConfigurations.work-wsl.pkgs.cacert.version` shows 3.131.1 or later.
  Reason: browsers block the intermediates through revocation, but curl, git and OpenSSL read
  only the system bundle, and nixos-26.05 still shipped cacert 3.126.
  On the Mac this covers only the Nix bundle. macOS's own `/usr/bin/curl`, `git` and `python3`
  read `/etc/ssl/cert.pem`, which Nix does not manage and macOS updates can restore. Patch it by
  hand with the site's command.
  Details: https://emudhra.we-have-a-problem.com/

## Deploys

- **Each lab box builds and applies itself from the repo on GitHub, with `rebuild`.** Any
  machine on the tailnet deploys over SSH: the Mac, WSL, or an orb as `orb`. There is no
  colmena, and root has no SSH key of its own.
  Reason: what runs on a box is always a commit. An orb's checkout goes away with the orb, so
  a deploy from it of changes that were not committed could leave a box with a configuration
  that exists nowhere. Each box evaluates itself, so no deploying machine needs the memory or
  the inputs. To try a change, push a branch and apply it with `rebuild test`.
- **The lab boxes keep a GitHub token and Rex's package token, through opnix.**
  Reason: a box fetches the flake's inputs itself. yonder is a private repo.
- **A lab box gets the opnix token once, at install.** It is copied again only when it is
  replaced (docs/secrets.md).
  Reason: colmena copied it at each deploy; without colmena, a deploy has no token to copy.

## Rex

Details: [Rex on the lab boxes](rex.md).

- **Every lab box runs Rex's login server, from the Rex flake's NixOS module.**
  Reason: each caller gets a Rex server as their own account, and sessions survive restarts
  and upgrades. The shared server runs everything as one `rex` account, and an upgrade ends
  every session.
- **The login server listens through Tailscale Serve, in HTTPS on Rex's port, 7297. Not on
  443, not on a plain tailnet address, and not through Rex's built-in Tailscale.**
  Reason: Rex for iOS needs HTTPS, which Serve gives with the tailnet's certificates, and the
  box's own tailscaled identifies callers. 443 stays free for anything else that serves HTTPS
  on a box. Serve and a plain listener can't share a port, and one listener is simpler.
  Built-in Tailscale would add each box to the tailnet a second time.
- **Every machine gets the same Rex keybinds (`home/files/rex`).**
  Reason: each Rex server reads its own `init.lua`, so a session on a lab box uses the box's.
- **The `snapshot` channel, pinned by `flake.lock`.** Rex updates with `nix flake update rex`,
  not by itself.
  Reason: it is the only supported way on NixOS.
- **Until Rex's first release, its package login is in 1Password and in an Amp project
  secret.** The Mac reads it with opnix; orbs get it from Amp.
  The lab boxes read it with opnix too.
  Reason: the flake input needs it wherever the lab boxes are evaluated: on the boxes
  (`rebuild`), the Mac (nixos-anywhere, `nix flake check`) and orbs (`nix flake check`).
  Without it in orbs, every orb's setup would fail.

## Project environments

- **direnv, with nix-direnv, loads project environments.** The mise `layouts` plugin from the old
  dotfiles is not used.

## Not decided

- The repo structure: layers, as now, or one file per feature, as in
  [Goxore/nixconf](https://github.com/Goxore/nixconf). Decide when the lab boxes get roles.
- The VM tool: microvm.nix, libvirt or incus.
- How remote agents are started and controlled.
