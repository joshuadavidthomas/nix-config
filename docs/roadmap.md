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
- [x] `lab-2` and `lab-3` members of `lab-1`'s yonder fabric (yonder M3); every lab box accepts the others' routes
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

- [ ] node_exporter, smartctl_exporter and Vector on the lab boxes, in
      `modules/nixos/server.nix`, sending nothing yet. Written; apply with `colmena apply`.
- [ ] Choose the series and journal priorities to keep, from the preview. See
      [Before shipping](research/homelab-monitoring.md#before-shipping).
- [ ] A Fly machine on the tailnet with VictoriaMetrics, VictoriaLogs, vmalert, Alertmanager
      and Grafana
- [ ] Vector ships to the Fly machine: replace its two sinks
- [ ] Alert rules in vmalert, and Alertmanager to Discord
- [ ] A heartbeat Worker on Cloudflare, which also relays alerts to hark
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
