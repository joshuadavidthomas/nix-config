# Set up NixOS-WSL

Last applied before the October 2026 changes to `home/`. Not tested since.

## What you need

- WSL from the Microsoft Store
- 1Password for Windows, with Settings > Developer > Use the SSH agent turned on

## Procedure

1. Download `nixos.wsl` from the
   [NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases/latest).
2. In PowerShell, install NixOS:

   ```powershell
   wsl --install --from-file nixos.wsl
   ```

3. Start NixOS:

   ```powershell
   wsl -d NixOS
   ```

4. Set a password for `nixos`:

   ```sh
   passwd
   ```

5. Put the age key on the machine. See
   [Put the age key on a machine](secrets.md#put-the-age-key-on-a-machine).
6. Apply the configuration from GitHub:

   ```sh
   sudo nixos-rebuild switch --flake github:joshuadavidthomas/nix-config#work-wsl \
     --option extra-experimental-features 'nix-command flakes'
   ```

   The first apply takes a long time. It clones the repo to `~/.nix-config`.

7. Close NixOS and start it again.
8. Make sure that the SSH agent shows your 1Password keys:

   ```sh
   ssh-add -l
   ```

9. Test SSH. GitHub replies with your username.

   ```sh
   ssh -T git@github.com
   ```

10. Log in to GitHub:

    ```sh
    gh auth login
    ```

11. Make a signed commit on a test branch. Push it. On GitHub, the commit shows "Verified".

To apply later:

```sh
sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
```

SSH settings go in `%USERPROFILE%\.ssh\config` on Windows. `ssh` runs `ssh.exe`.

To get the age key from 1Password at each apply, set `secrets.op` in
`hosts/work-wsl/default.nix` to the Windows `op.exe` (unverified).

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| Certificate errors on downloads | The network inspects TLS | Export the company root CA from Windows. Add it to `security.pki.certificateFiles` in `hosts/work-wsl/default.nix`. |
| `Failed to start the systemd user session for 'nixos'` | Another WSL distribution uses the session for user ID 1000 | Run `wsl --shutdown`. Start NixOS before other distributions. |
| Each apply ends with exit status 4 | The same as above | The same as above |
| `cannot execute binary file` for a Windows program | WSL interop is not registered | Keep `wsl.interop.register = true` |
| A downloaded program shows `No such file or directory` | NixOS has no standard dynamic loader | Keep `programs.nix-ld.enable = true` |
