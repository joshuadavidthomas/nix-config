# Set up NixOS-WSL

This procedure installs NixOS as a WSL distribution and applies the `work-wsl` host.

> **Caution:** The `work-wsl` host has not been applied since the Mac changes to `home/`.
> Expect 1Password CLI warnings and long builds. See the [roadmap](roadmap.md#wsl).

## Install NixOS-WSL

You need the Microsoft Store version of WSL.

1. Download `nixos.wsl` from the
   [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases/latest).
2. In PowerShell, install and start it:

   ```powershell
   wsl --install --from-file nixos.wsl
   wsl -d NixOS
   ```

3. Set a password for the `nixos` user:

   ```sh
   passwd
   ```

4. Update the channel:

   ```sh
   sudo nix-channel --update
   ```

## Apply the configuration

1. Apply the configuration from GitHub:

   ```sh
   sudo nixos-rebuild switch --flake github:joshuadavidthomas/nix-config#work-wsl \
     --option extra-experimental-features 'nix-command flakes'
   ```

   This also clones the repo to `~/.nix-config`.

2. To apply changes later, use the local clone:

   ```sh
   sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
   ```

If downloads fail with certificate errors, the network inspects TLS. Export the company root
CA from Windows. Add it to `security.pki.certificateFiles` in `hosts/work-wsl/default.nix`.
Then apply again.

## Connect 1Password

SSH and git signing use 1Password on Windows.

1. In 1Password for Windows, turn on Settings > Developer > Use the SSH agent.
2. In WSL, list the keys. You should see your 1Password keys.

   ```sh
   ssh-add -l
   ```

3. Test SSH to GitHub. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

4. Log in to GitHub:

   ```sh
   gh auth login
   ```

5. Make a signed commit on a test branch. Push it, and make sure GitHub shows "Verified".

In WSL, `ssh` and `ssh-add` are aliases for `ssh.exe` and `ssh-add.exe`. If the shell cannot
find them, WSL interop is off. SSH reads its config from `%USERPROFILE%\.ssh\config` on
Windows.

If signing fails, compare `signing.signer` in `hosts/work-wsl/default.nix` with the snippet
from 1Password. To get the snippet, open the key in 1Password and select Configure Commit
Signing. Tick the WSL option, then select Copy Snippet.

## If other distributions are running

Another distribution can hold the systemd session for user ID 1000. Then NixOS shows
`Failed to start the systemd user session for 'nixos'`, and each switch ends with exit
status 4. The system configuration still applies.

To prevent this:

1. Start NixOS first: run `wsl --shutdown`, then `wsl -d NixOS`.
2. In Docker Desktop, open Settings > Resources > WSL integration. Turn off the distributions
   that you do not use.
3. Make NixOS the default: `wsl --set-default NixOS`.

## Remove an old distribution

1. Export the distribution. `wsl --import` can restore it from this file.

   ```powershell
   wsl --shutdown
   wsl --export Ubuntu D:\wsl-backups\ubuntu.tar
   ```

2. Copy the files that you need through `C:`:

   ```sh
   # in Ubuntu
   tar czf /mnt/c/Users/jthomas/from-ubuntu.tgz -C ~ .gnupg src/some-repo
   # in NixOS
   mkdir -p ~/from-ubuntu && tar xzf /mnt/c/Users/jthomas/from-ubuntu.tgz -C ~/from-ubuntu
   ```

3. Add tools to `home.packages` when you need them. Do not put keys or `.env` files in this
   repo.
4. After a week without the old distribution, remove it:

   ```powershell
   wsl --unregister Ubuntu
   ```
