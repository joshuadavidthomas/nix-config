# Decisions

The owner made these decisions. Each one has its reason. Progress on them is in the
[roadmap](roadmap.md).

## Machines

- **One user, `josh`, on every machine.** The lab boxes add `orb`, for Amp orbs.
- **The Steam Deck keeps Valve's SteamOS and Valve's own `deck` user.** It is not a NixOS
  machine. `homeConfigurations.deck` applies the shared `home/` to it with standalone
  home-manager, over the official Nix installer with its Steam Deck mode. Determinate Nix
  does not install there: the write of `determinate-nixd` needs a `/usr/local/bin` that
  SteamOS's read-only root does not allow (nix-installer issue #1285).
  Reason: keeping SteamOS keeps the gaming environment and Valve's hardware support, which is
  the machine's job, and the installer's `/home/nix` store survives SteamOS updates. The lab
  machines' model (`rebuild`, system modules, monitoring) stays theirs for now.
- **The Deck's login shell stays `bash`; `fish` starts by hand.**
  Reason: a SteamOS update resets `/etc/shells`, and a login shell that is not in it keeps
  both the desktop and SSH from logging in, an outage that looks like a dead machine
  ([SteamOS issue #2922](https://github.com/ValveSoftware/SteamOS/issues/2922)).
- **The Deck gets system integration in stages, and what it gets runs itself.** Stage 2 adds
  the secrets (opnix at the home-manager level, its token in the home at
  `~/.config/opnix/token`), the keep-list and Rex's login server, through the pinned
  steamos-etc-nix — plus one unit of its own: an every-boot lookup of
  `/etc/atomic-update.conf.d`, so an update never blocks on a frozen `/var`. Applies over the
  tailnet and monitoring still wait for the runbook to survive a SteamOS update and a cold
  reboot without a session. Stages: [Set up the Steam Deck](roadmap.md#steam-deck).
  Reason: SteamOS updates drop `/etc` files that no keep-list entry covers and hang
  mid-update on any keep-list entry at all
  ([Valve issue #2957](https://github.com/ValveSoftware/SteamOS/issues/2957)). Nothing may
  depend on home-manager state that the machine's own state files do not survive.
- **The Deck keeps Valve's SteamOS and its own tailscaled.** SteamOS tailscaled comes from the
  Tailscale script's layout (`/opt/tailscale`, on the home partition) and its keep-listed
  files, which this repo does not manage. It serves SSH, once enabled on the Deck. The CLI
  that talks to it in the repo's `rex-tailscale-serve` unit is that daemon's own build, so
  the two cannot drift.
  Reason: replacing an installation that works would only add drift, and it is the only
  connection that an apply comes through today.
- **The Deck keeps opnix's home-manager module.** On the machines NixOS and macOS configure,
  opnix runs as a system service, and the home-manager writes no secrets. The Deck is
  different: it has no system service, so the secrets come in at the home level, and this is
  the one module that uses the HM module (`hosts/deck/default.nix`).
  Reason: the HM module carries its own way of applying the secrets, so atuin's login and
  the signing key land without a system unit that SteamOS would drop on the next update. opnix
  does fail clean on a missing token.
- **The Deck's suspend is blocked by a system unit, not by a SteamOS setting.** While the
  Deck is docked, `deck-always-on` holds a logind inhibitor open, which every sleep path
  honors; the screen still goes dark, and CPU, Wi-Fi and services run behind it. A deliberate
  suspend means stopping the unit first, on purpose
  ([Set up the Steam Deck](new-deck.md#staying-on-while-docked)).
  Reason: a setting in Valve's own screens would be unowned and unrecorded, and Valve moves
  them; one keep-listed unit in the repo is the machine's own record.
- **Rex runs on the Deck like the lab boxes.** The login server as a system unit through
  steamos-etc, identified against the deck's own tailscaled, reachable through Tailscale
  Serve on 7297, and a single policy file `/etc/rex/accounts.jsonc` mapping the owner's
  Tailscale login to the account `deck`. It is one root process, one Serve mapping, no
  second tailnet identity. It runs `--pam=false`: a prebuilt rex binary cannot dlopen
  SteamOS's PAM modules (their libraries sit off its loader path), so rex's shadow checks
  do the admission, its container mode. The lab boxes keep the Rex module's own PAM stack.
  The account differs from the lab boxes: `deck`, not `josh`, the
  one account exception above.
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
- **The Steam Deck is a tagged node, with the tag `deck`.** It carries no personal identity,
  and its key does not expire.
  Reason: it is a machine, not a personal device, on the same tailnet, and it should outlive
  a login the same way the lab boxes do. Tagging after today's login was a console action
  (the deck was already enrolled); a tag applied that way does not clear a key's expiry, so
  the expiry was switched off by hand in the same place
  ([Set up the Steam Deck](new-deck.md#on-the-tailnet)).

## Monitoring

Design: [Homelab monitoring](research/homelab-monitoring.md).

- **The monitoring machine on Fly joins the tailnet.** The lab boxes send to it over
  Tailscale, and Grafana is reached over Tailscale.
  Reason: the lab is a trusted network behind Tailscale. VictoriaMetrics and VictoriaLogs have
  no per-client auth, and a public endpoint would need a token on each lab box.
- **Grafana signs you in with your Tailscale identity.** `tailscale serve` passes the user's
  login, and Grafana trusts it from 127.0.0.1 only. New users are Viewers; the owner is Admin.
  `admin` with its password stays, for the API, as the break-glass.
  Reason: no Grafana password to keep for everyday use, and the tailnet already says who you
  are. A role is never taken from a header: serve strips only its own headers, so a role
  header would be the client's to set.
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
- **A weekly GitHub Actions workflow opens a pull request that updates `flake.lock`.** It
  updates every input except `rex` and `yonder`, which are updated by hand. Merging it is
  still a manual step.
  Reason: the lock went a month without an update (nixpkgs pinned at October 7), so the lab
  boxes stayed on kernel 6.18.55 after its fix shipped. CI has no Rex login and no access to
  the private yonder repo.
- **topgrade updates what Nix does not pin. Run it by hand about once a week, after the Nix
  update.** Steps are in [Update everything](changes.md#update-everything).
  Reason: the Mac keeps its sudo password, so a scheduled run cannot finish. A run by hand
  also shows what changed, when a beta tool breaks.
- **topgrade does not run its `system` step on NixOS.**
  Reason: that step runs `nixos-rebuild` without `--flake`, which builds `/etc/nixos`, not
  this repo.

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
