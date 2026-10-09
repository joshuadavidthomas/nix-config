# Set up NixOS-WSL

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

3. Start NixOS. You are the user `nixos`.

   ```powershell
   wsl -d NixOS
   ```

4. Apply the configuration from GitHub. Use `boot`, not `switch`: the configuration replaces
   the user `nixos` with `josh`.

   ```sh
   sudo nixos-rebuild boot --flake github:joshuadavidthomas/nix-config#work-wsl \
     --option extra-experimental-features 'nix-command flakes'
   ```

   The first apply takes a long time.

5. Exit NixOS. In PowerShell, start NixOS once as root, then stop it:

   ```powershell
   wsl -t NixOS
   wsl -d NixOS --user root exit
   wsl -t NixOS
   ```

6. Start NixOS. You are the user `josh`. The first start clones the repo to `~/.nix-config`.
7. Set a password:

   ```sh
   passwd
   ```

8. Put the age key on the machine. See
   [Put the age key on a machine](secrets.md#put-the-age-key-on-a-machine).
9. Apply again:

   ```sh
   sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
   ```

10. Close NixOS and start it again.
11. Make sure that the SSH agent shows your 1Password keys:

    ```sh
    ssh-add -l
    ```

12. Test SSH. GitHub replies with your username.

    ```sh
    ssh -T git@github.com
    ```

13. Log in to GitHub:

    ```sh
    gh auth login
    ```

14. Make a signed commit on a test branch. Push it. On GitHub, the commit shows "Verified".

To apply later:

```sh
sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
```

SSH settings go in `%USERPROFILE%\.ssh\config` on Windows. `ssh` runs `ssh.exe`.

To get the age key from 1Password at each apply, set `secrets.op` in
`hosts/work-wsl/home.nix` to the Windows `op.exe` (unverified).

## Rename the user on an installed system

An install from before the rename has the user `nixos`. Do this once.

1. Update `~/.nix-config`:

   ```sh
   git -C ~/.nix-config pull
   ```

2. Apply with `boot`, not `switch`:

   ```sh
   sudo nixos-rebuild boot --flake ~/.nix-config#work-wsl
   ```

3. Exit NixOS. In PowerShell, start NixOS once as root, then stop it:

   ```powershell
   wsl -t NixOS
   wsl -d NixOS --user root exit
   wsl -t NixOS
   ```

4. Start NixOS. You are the user `josh`, with the user ID that `nixos` had. Your old files
   are in `/home/nixos`.
5. Move the age key:

   ```sh
   mkdir -p -m 700 ~/.config/sops/age
   mv /home/nixos/.config/sops/age/keys.txt ~/.config/sops/age/
   ```

6. Move the other directories that you want to keep, for example your projects:

   ```sh
   mv /home/nixos/<directory> ~/
   ```

7. Apply again. This logs atuin in and syncs your history.

   ```sh
   sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl
   ```

8. Log in to GitHub:

   ```sh
   gh auth login
   ```

9. When `/home/nixos` has nothing more that you need, remove it:

   ```sh
   sudo rm -rf /home/nixos
   ```

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| Certificate errors on downloads | The network inspects TLS | Export the company root CA from Windows. Add it to `security.pki.certificateFiles` in `hosts/work-wsl/default.nix`. |
| `Failed to start the systemd user session for 'josh'` | Another WSL distribution uses the session for user ID 1000 | Run `wsl --shutdown`. Start NixOS before other distributions. |
| Each apply ends with exit status 4 | The same as above | The same as above |
| `cannot execute binary file` for a Windows program | WSL interop is not registered | Keep `wsl.interop.register = true` |
| A downloaded program shows `No such file or directory` | NixOS has no standard dynamic loader | Keep `programs.nix-ld.enable = true` |
