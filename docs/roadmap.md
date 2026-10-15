# Roadmap

## WSL

- [x] Apply `work-wsl` with the new `home/`
- [x] Test commit signing with `op-ssh-sign.exe`
- [ ] Rename the user to `josh` on the work laptop. See
      [Rename the user on an installed system](new-wsl.md#rename-the-user-on-an-installed-system).

## Homelab

- [x] Set up `lab-2` and `lab-3`
- [ ] A binary cache on one lab box
- [ ] Lab boxes as remote builders for each other and for the Mac
- [ ] `system.autoUpgrade` on the lab boxes
- [x] yonder on `lab-1` from its NixOS module (yonder M2), shipped to with yonder's `tests/lab/deploy.sh`
- [x] yonder's module on `lab-2` and `lab-3`, the same way (for yonder M3)
- [x] All three lab boxes members of the yonder fabric, coordinated by `yonder-coordinator` on Fly (yonder M3); every lab box accepts the others' routes
- [ ] Optional: install lab boxes again with an XFS root, one at a time, for yonder's reflink
      clones. See [Decisions](decisions.md#machines).

## Secrets

See [Decisions](decisions.md#secrets).

- [x] Create the vault `dotfiles` and a read-only service account for it
- [x] Read secrets from 1Password with opnix, on every machine
- [x] Remove sops: atuin, the MonoLisa fonts (as 1Password Documents), the age key
- [ ] Apply on WSL, so that it gets the opnix token. The Mac and the lab boxes are done.
- [ ] Delete the 1Password document "nix-config sops age key"
- [x] A shared signing key for the lab boxes
- [x] Register the lab signing key on GitHub
- [x] A new lab box joins Tailscale by itself, with the tag `lab`
- [x] Make the Tailscale OAuth client and its item in 1Password. See
      [The Tailscale client](secrets.md#the-tailscale-client).
- [x] Give `lab-1` the tag `lab`
- [ ] Turn off `lab-1`'s key expiry in the Tailscale admin console. It has the tag but still
      expires on 2027-04-07, because it was tagged after it logged in.
- [x] Give `lab-2` and `lab-3` the tag `lab`, in the Tailscale admin console
- [ ] Turn off `lab-2`'s and `lab-3`'s key expiry there: a tag set in the console does not
      change it, only a new login does.
- [ ] After a few days of use, check `op service-account ratelimit`

## Monitoring

Design: [Homelab monitoring](research/homelab-monitoring.md).

- [x] node_exporter, smartctl_exporter and Vector on the lab boxes, in
      `modules/nixos/server.nix`, sending nothing yet
- [x] Choose the series and journal priorities to keep, from the preview. See
      [What the lab boxes send](research/homelab-monitoring.md#what-the-lab-boxes-send).
- [x] Drive health on `lab-1`, `lab-2` and `lab-3`: the `udevadm` command in
      [What the lab boxes send](research/homelab-monitoring.md#what-the-lab-boxes-send)
- [x] `tag:monitor` in the tailnet policy (tailscale-acls #10)
- [x] The monitor in `monitor/`: Tailscale, VictoriaMetrics, VictoriaLogs and Grafana. Tested
      on Fly without Tailscale. See [The monitor](monitor.md).
- [x] The monitor's Tailscale client, its secret in the Fly app, and the first deploy
- [x] Vector ships to the monitor
- [x] Grafana: Node Exporter Full and the SMART dashboard, and the `instance` and `job` labels
      they need
- [x] vmalert, Alertmanager and alert rules on the monitor. See
      [Alerts](monitor.md#alerts).
- [x] Grafana that feels live: 10 s sampling for what is watched, and an overview dashboard
- [ ] Backups of the monitor's volume to R2. Fly keeps a daily snapshot for 5 days already.
- [x] A relay from Alertmanager to hark, and only the alerts that need you soon
- [ ] In about a month, review how often each alert fired and whether it needed you
- [x] A heartbeat outside the monitor: a Cloudflare Worker (`monitor/heartbeat`)
- [x] Test the heartbeat for real: stop the monitor for 6 minutes. "Monitor silent" and
      "Resolved" arrived; so did a false `BoxSilent` for lab-3, fixed with a `for: 2m`.
- [x] On-call pages (a sound, repeated until acknowledged) for a box silent, a
      failing drive and the monitor silent. Tested on 2026-10-15: a fake box's page, and the
      monitor stopped for 7 minutes.
- [x] Dashboards, one for each job (Homelab, Capacity, VMs, Machine, Logs, Monitor), for any
      number of machines; the monitor scrapes its own services
- [ ] Per-VM CPU and memory, from yonderd's own metrics
- [ ] Find out why data queued during an outage arrives thinned: 1–2 samples a minute, not 6
- [ ] Agent access through the VictoriaMetrics MCP server
- [ ] A second Vector sink to Cloudflare Basin

## Mac

- [ ] Declare the apps that Homebrew does not install
- [ ] Declare macOS settings: Finder, trackpad, appearance
- [ ] Declare login items
- [ ] Move the remaining tokens (Claude, gh, Todoist) into 1Password
- [ ] Garbage collection

## All machines

- [ ] Pin SSH host keys (GitHub, Forgejo, lab boxes) in `modules/known-hosts.nix`
- [ ] A CI job that opens pull requests for `flake.lock` updates
