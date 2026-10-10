# Set up a lab box

The examples use `lab-2`. Use the next free number.

## What you need

- The lab box, connected to ethernet
- A USB stick with the NixOS minimal ISO
- The Mac, with the configuration applied

## Add the lab box to the repo

1. On the Mac, in `~/.nix-config`, copy a lab box:

   ```sh
   cp -r hosts/lab-1 hosts/lab-2
   ```

2. Empty the hardware configuration:

   ```sh
   echo '{ }' > hosts/lab-2/hardware-configuration.nix
   ```

3. Run `jj status`.
4. In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`.
5. In `flake.nix`, add `"lab-2"` to `labs`.

## Prepare the lab box

1. In the BIOS, turn on UEFI.
2. In the BIOS, turn off Secure Boot.
3. Start from the USB stick.
4. Set a password for the installer:

   ```sh
   passwd
   ```

5. Write down the IP address and the MAC address:

   ```sh
   ip a
   ```

6. Write down the disk name, for example `nvme0n1`:

   ```sh
   lsblk
   ```

7. If the disk is not `nvme0n1`, set it in `hosts/lab-2/default.nix` on the Mac:
   `disko.devices.disk.main.device = "/dev/sda";`.

## Install

> **Warning:** The next command erases the disk of `lab-2`: `/dev/nvme0n1`, or the disk that
> `hosts/lab-2/default.nix` sets. The layout is in `modules/nixos/single-disk.nix`.

1. On the Mac, go to `~/.nix-config`.
2. Run nixos-anywhere. Paste the command as one line.

   ```sh
   nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --build-on remote
   ```

3. Enter the installer password when asked.

The output ends with `Connection refused` and `### Done! ###`. That is the restart.

## Connect to Tailscale

1. Find the new IP address of the lab box. Look for its MAC address in the DHCP client list
   of the router.
2. Start Tailscale on the lab box:

   ```sh
   ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> sudo tailscale up
   ```

3. Open the URL that the command shows. Approve the lab box.
4. Connect by name. The output shows the NixOS version.

   ```sh
   ssh lab-2 nixos-version
   ```

## Put the token on the lab box

1. Put the service account token on the lab box:

   ```sh
   op read "op://Private/Service Account Auth Token: dotfiles/credential" | ssh lab-2 sudo opnix token set
   ```

2. Fetch the secrets. This also logs atuin in.

   ```sh
   ssh lab-2 sudo systemctl restart opnix-secrets home-manager-josh
   ```

## Record and apply

1. Record the change:

   ```sh
   jj describe -m "Add lab-2"
   jj new
   ```

2. Apply:

   ```sh
   colmena apply --on lab-2
   ```

   The output ends with `Activation successful`.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `Too many authentication failures` | SSH offered too many 1Password keys | Use `--ssh-option IdentityAgent=none` for the installer. Use `-o IdentitiesOnly=yes -i ~/.ssh/lab.pub` for an installed lab box. |
| `kex_exchange_identification: read: Connection reset by peer`, but ping works | sshd blocks the Mac after many failed logins | On the lab box, run `sudo systemctl restart sshd` |
| nixos-anywhere asks for the `root@…` password again and again | The command has `PubkeyAuthentication=no` | Press Ctrl-C. Use `IdentityAgent=none`. The disk is not changed yet. |
| The lab box does not answer after the install | The IP address changed | Find the MAC address on the router. On macOS, `arp -an` shows MAC addresses without leading zeros. |
| The lab box is not on the router | NixOS did not start | Look at the screen. The lab box can be in the BIOS boot menu or on the USB stick. |
