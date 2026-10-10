# Decisions

The owner made these decisions. Each one has its reason. Progress on them is in the
[roadmap](roadmap.md).

## Machines

- **One user, `josh`, on every machine.**
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

## Network

- **The lab is a trusted network behind Tailscale.** The lab boxes are not open to the
  internet. Where simple and hardened conflict, choose simple.

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

## Project environments

- **direnv, with nix-direnv, loads project environments.** The mise `layouts` plugin from the old
  dotfiles is not used.

## Not decided

- The repo structure: layers, as now, or one file per feature, as in
  [Goxore/nixconf](https://github.com/Goxore/nixconf). Decide when the lab boxes get roles.
- The VM tool: microvm.nix, libvirt or incus.
- How remote agents are started and controlled.
