# WSL

The work laptop runs NixOS as a WSL distribution, with the `work-wsl` host. The user is
`nixos`. Work settings (email, certificates, proxies) go in `hosts/work-wsl`, not in `home/`.

## Set up NixOS-WSL

You need the Microsoft Store version of WSL.

1. Download `nixos.wsl` from the
   [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases/latest).
2. In PowerShell, install and start it:

   ```powershell
   wsl --install --from-file nixos.wsl
   wsl -d NixOS
   ```

3. Set a password for `nixos`:

   ```sh
   passwd
   ```

4. Put the sops age key on the machine. Copy the 1Password document "nix-config sops age key"
   to `~/.config/sops/age/keys.txt`. See [Secrets](secrets.md#put-the-key-on-a-machine).

   > **Note:** The configuration cannot get the key from 1Password on WSL. `secrets.op` points
   > to the Mac path of `op`.

5. Apply the configuration from GitHub:

   ```sh
   sudo nixos-rebuild switch --flake github:joshuadavidthomas/nix-config#work-wsl \
     --option extra-experimental-features 'nix-command flakes'
   ```

   This clones the repo to `~/.nix-config`. The first switch builds some packages from
   source, so it takes a long time.

6. From now on, apply from the clone:

   ```sh
   sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
   ```

If downloads fail with certificate errors, the network inspects TLS. Add the company root CA
to `security.pki.certificateFiles` in `hosts/work-wsl/default.nix`.

## Connect 1Password

SSH and git signing use 1Password on Windows. In WSL, `ssh` and `ssh-add` are aliases for
`ssh.exe` and `ssh-add.exe`. SSH reads its config from `%USERPROFILE%\.ssh\config`.

1. In 1Password for Windows, turn on Settings > Developer > Use the SSH agent.
2. List the keys. You should see your 1Password keys.

   ```sh
   ssh-add -l
   ```

3. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

4. Log in to GitHub:

   ```sh
   gh auth login
   ```

5. Make a signed commit on a test branch. Push it. Make sure that GitHub shows "Verified".

If signing fails, compare `signing.signer` in `hosts/work-wsl/default.nix` with the snippet
from 1Password. In 1Password, open the key, select Configure Commit Signing, tick the WSL
option, and select Copy Snippet. The repo uses `op-ssh-sign.exe`. If git reports a path
error, try `op-ssh-sign-wsl.exe`.

## Problems

| Problem | Cause | Action |
| --- | --- | --- |
| `cannot execute binary file` for a Windows `.exe` | WSL interop is not registered | Keep `wsl.interop.register = true` |
| `Failed to start the systemd user session`, or each switch ends with exit status 4 | Another distribution holds the session for user ID 1000 | Run `wsl --shutdown`, then start NixOS first. Turn off WSL integration in Docker Desktop for the distributions that you do not use. |
| A downloaded program fails with `No such file or directory` | NixOS has no standard dynamic loader | Keep `programs.nix-ld.enable = true` |
