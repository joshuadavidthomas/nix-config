# How to set up NixOS-WSL on a Windows laptop

This installs NixOS as a WSL distro beside any existing one and applies the `work-wsl` host.

> The `work-wsl` host hasn't been rebuilt since the Mac work reshaped `home/`. Expect warnings
> about the 1Password CLI, and long builds of atuin, cf, lisette and llm. See the
> [roadmap](../roadmap.md#still-open) before relying on it.

## Install NixOS-WSL

You need the Microsoft Store version of WSL. Download `nixos.wsl` from the
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases/latest), then in
PowerShell:

```powershell
wsl --install --from-file nixos.wsl
wsl -d NixOS
```

The default user is `nixos`. Inside the distro, set a password and update the channel the image
starts on:

```sh
passwd
sudo nix-channel --update
```

## Apply this repo

Switch straight from GitHub. The flake turns on flakes itself, so `--extra-experimental-features`
is only needed for this first run:

```sh
sudo nixos-rebuild switch --flake github:joshuadavidthomas/nix-config#work-wsl \
  --option extra-experimental-features 'nix-command flakes'
```

The switch clones this repo to `~/.nix-config`. From then on, apply changes with:

```sh
sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
```

If downloads fail with certificate errors, the corporate network is inspecting TLS. Export the
company root CA from Windows, add it with `security.pki.certificateFiles` in
`hosts/work-wsl/default.nix`, and switch again.

## Connect 1Password

SSH and git signing go through 1Password on the Windows side. In 1Password for Windows, turn on
the SSH agent. Then, in WSL:

```sh
ssh-add -l                  # aliased to ssh-add.exe; should list your 1Password keys
ssh -T git@github.com       # aliased to ssh.exe; should greet you by username
gh auth login               # also lets Nix use gh's token for GitHub fetches
```

If `ssh-add.exe` isn't found, WSL interop is off. SSH config for WSL lives in
`%USERPROFILE%\.ssh\config` on Windows, because `ssh.exe` reads that file.

To check commit signing, make a signed commit on a scratch branch and confirm GitHub marks it
Verified. If signing fails, compare `signing.signer` in `hosts/work-wsl/default.nix` with
1Password's own snippet (open the key in 1Password, Configure Commit Signing, tick the WSL
option, Copy Snippet).

## If other WSL distros are running

If NixOS reports `Failed to start the systemd user session for 'nixos'`, or every
`nixos-rebuild switch` ends with exit status 4, another distro is holding the UID-1000 user
session. The system config still applies. To avoid it:

- Start NixOS first: `wsl --shutdown`, then `wsl -d NixOS`.
- In Docker Desktop, under Settings > Resources > WSL integration, turn off integration for
  distros you don't need.
- Make NixOS the default with `wsl --set-default NixOS`.

## Move off an old distro

Export it first; `wsl --import` restores the tar exactly:

```powershell
wsl --shutdown
wsl --export Ubuntu D:\wsl-backups\ubuntu.tar
```

Then move things over as you need them. Tools go into `home.packages`, dotfiles into
home-manager, and repos get re-cloned. Copy keys and `.env` files by hand; they never go in
this repo. To copy files across, stage them on `C:`:

```sh
# in Ubuntu
tar czf /mnt/c/Users/jthomas/from-ubuntu.tgz -C ~ .gnupg src/some-repo
# in NixOS
mkdir -p ~/from-ubuntu && tar xzf /mnt/c/Users/jthomas/from-ubuntu.tgz -C ~/from-ubuntu
```

Once you've gone a week without opening the old distro, remove it with
`wsl --unregister Ubuntu`. The exported tar stays as the safety net.
