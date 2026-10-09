# About the homelab

The homelab is a set of NixOS boxes, `lab-1`, `lab-2` and so on, that share one module,
`modules/server.nix`. Each box adds only its hostname, its disk layout and the hardware config
generated when it was installed. The Mac controls all of them, but never builds anything for
them.

## Installing and deploying

Two tools split the job. nixos-anywhere does the install: it connects to a box booted from the
NixOS installer, partitions the disk with disko, builds the system and installs it. colmena
deploys every change after that. Both run from the Mac, and with `--build-on remote` and
`deployment.buildOnTarget` every build happens on the box itself. That matters because the
Mac is ARM and the boxes are x86_64; without it the Mac would need a Linux builder.

The two tools read different flake outputs: nixos-anywhere installs
`nixosConfigurations.lab-N`, and colmena deploys `colmenaHive`. They have to build the same
system, or the first deploy quietly changes what was installed. The hive used to list its own
modules, and that missed the module nixpkgs adds inside `nixosSystem`, which carries the
version label and the `nixpkgs` registry pin. The first deploy left `lab-1` calling itself
`26.05pre-git`. Now each hive node imports its `nixosConfigurations` entry's module list, and
the hive sets the version label from the flake, so the two build identical systems.

Both outputs come from the `labs` list in `flake.nix`, so adding a box is a name in that list
and a copy of a host directory.

## Reaching the boxes

The boxes trust one SSH key, the "Mac mini" key in 1Password, for both `josh` and `root`;
colmena deploys as root. 1Password's agent holds eleven keys, and SSH offers every one of
them, while sshd stops after six attempts and starts blocking the address after repeated
failures. So `hosts/mac/home.nix` writes the trusted key's public half to `~/.ssh/lab.pub`
and tells SSH to offer only that key to `lab-*`. The private key never leaves 1Password.

The installer is the awkward moment, because it trusts no key at all. The plan was to set a
password on it and SSH in, and that works only if the agent is kept out of the way, hence
`--ssh-option IdentityAgent=none`. The tempting alternative, `PubkeyAuthentication=no`,
breaks the install: nixos-anywhere logs in once with the password, installs its own temporary
key, and connects as root with that key. With key logins off, it asks for a root password the
installer doesn't have.

After the install, the boxes are addressed by name over Tailscale (MagicDNS), which is also
how colmena finds them. LAN addresses aren't stable: `lab-1`'s changed between the installer
and the installed system.

## Where it's going

The next pieces build on each other. Secrets come first: sops with age keys derived from each
box's SSH host key (`ssh-to-age`), starting with a Tailscale auth key so joining the tailnet
becomes part of the config. Then a binary cache on one box (harmonia), so each package builds
once. Then the boxes as remote builders for each other and for the Mac, which is how the Mac
would build Linux systems without a VM.

The builder setup has two traps worth knowing in advance. Builds run as the Nix daemon (root),
which can't reach 1Password, so the builder key has to come from sops. And the builders' host
keys need pinning, because daemon-to-daemon SSH has nobody to answer a first-connection
prompt.

More machines come only when builds actually queue.
