# About the homelab

The homelab boxes are named `lab-1`, `lab-2` and so on. They share one module,
`modules/server.nix`. Each box has a small directory with its hostname, its disk layout and
its hardware configuration. The Mac controls the boxes, but the boxes do their own builds.

## Install and deploy

Two tools do the work:

- nixos-anywhere installs a box. It connects to the NixOS installer on the box and partitions
  the disk with disko. Then it builds the system and installs it.
- colmena deploys each later change.

Both run on the Mac. The builds run on the boxes, because of `--build-on remote` and
`deployment.buildOnTarget`. The Mac is ARM and the boxes are x86_64. Without remote builds,
the Mac would need a Linux builder.

The two tools use different flake outputs. nixos-anywhere installs
`nixosConfigurations.lab-N`. colmena deploys `colmenaHive`. They must build the same system.
If not, the first deploy changes the installed system.

At first, the hive had its own list of modules. That list did not have the module that
`nixosSystem` adds, which sets the version label and the `nixpkgs` registry. After the first
deploy, `lab-1` showed its version as `26.05pre-git`. Now each hive node imports the module
list of its `nixosConfigurations` entry, and the hive sets the version label. The two tools
now build the same system.

Both outputs come from the `labs` list in `flake.nix`. To add a box, add a name to the list
and copy a host directory.

## SSH access

The boxes accept one SSH key, the "Mac mini" key in 1Password, for `josh` and `root`. colmena
deploys as `root`.

The 1Password agent has eleven keys, and SSH tries each one. sshd stops after six tries. After
more failures, sshd blocks the Mac for some minutes. So `hosts/mac/home.nix` writes the public
part of the key to `~/.ssh/lab.pub`, and tells SSH to use only that key for `lab-*`. The
private key stays in 1Password.

The installer accepts no key. It accepts only the password that you set on it. For a password
login, SSH must not try the 1Password keys, so the install command has
`--ssh-option IdentityAgent=none`.

Do not use `PubkeyAuthentication=no` for this. nixos-anywhere logs in once with the password
and adds its own temporary key. Then it connects as `root` with that key. If key logins are
off, it asks for a `root` password. The installer has no `root` password.

After the install, the Mac connects to the boxes by name through Tailscale. colmena uses these
names too. The LAN address can change: the address of `lab-1` changed during its install.

## Next steps

Each step needs the one before it:

1. Secrets on the boxes. sops will use age keys made from the SSH host key of each box
   (`ssh-to-age`). The first secret will be a Tailscale auth key, so the configuration can
   connect the box to Tailscale.
2. A binary cache on one box (harmonia). Then each package builds only once.
3. Remote builds. The boxes build for each other and for the Mac. Then the Mac can build Linux
   systems without a virtual machine.

Remote builds have two requirements:

- The Nix daemon runs the builds as `root`, and `root` cannot use 1Password. So the builder
  key must come from sops.
- The host keys of the builders must be pinned. The daemon cannot answer a prompt for a new
  host key.

Add more boxes only when builds wait in a queue.
