# How to install a homelab box

This procedure installs NixOS on a box from the Mac. The examples use `lab-2`. Use the next
free number.

You need:

- the box, connected by ethernet
- a USB stick with the NixOS minimal ISO
- a Mac set up from this repo

## 1. Add the box to the repo

1. Copy an existing host:

   ```sh
   cp -r hosts/lab-1 hosts/lab-2
   echo '{ }' > hosts/lab-2/hardware-configuration.nix
   ```

2. In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`.
3. In `flake.nix`, add `"lab-2"` to `labs`.

## 2. Boot the installer

1. In the BIOS, turn on UEFI. Turn off Secure Boot.
2. Boot from the USB stick.
3. On the console of the box, set a password for the installer:

   ```sh
   passwd
   ```

4. Get the IP address and the MAC address:

   ```sh
   ip a
   ```

5. Get the disk name, for example `nvme0n1`:

   ```sh
   lsblk
   ```

6. In `hosts/lab-2/disk.nix`, set `device = "/dev/nvme0n1";`.

> **Warning:** The install erases this disk.

## 3. Install

1. On the Mac, go to `~/.nix-config`.
2. Run this command as one line:

   ```sh
   nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --build-on remote
   ```

3. Enter the installer password when asked.

The command partitions the disk, builds the system on the box, installs it and reboots the
box. It ends with `Connection refused` and `### Done! ###`. This is the reboot, not an error.

> **Note:** Do not split the command over lines. A blank line in a paste ends the command
> and drops the flags after it.

## 4. Join Tailscale

1. Find the IP address of the box. It can be different from the installer's address. If the
   old address does not answer, find the MAC address in the DHCP client list on the router.
2. Start Tailscale on the box:

   ```sh
   ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> sudo tailscale up
   ```

3. Open the URL that the command prints. Approve the box.

You can now connect with `ssh lab-2`.

## 5. Record and deploy

1. Record the change:

   ```sh
   jj describe -m "Add lab-2" && jj new
   ```

2. Deploy to the box:

   ```sh
   colmena apply --on lab-2
   ```

The deploy ends with `Activation successful`.

## Problems

| Problem | Cause | Action |
| --- | --- | --- |
| `Too many authentication failures`, or `Connection reset by peer` while ping works | sshd blocks the Mac after too many failed keys | On the box, run `sudo systemctl restart sshd`. Make sure that the command has `--ssh-option IdentityAgent=none`. |
| nixos-anywhere asks for a `root@…` password again and again | The command has `--ssh-option PubkeyAuthentication=no` | Press Ctrl-C. Use `--ssh-option IdentityAgent=none`. The disk is not changed yet. |
| The box does not answer after the install | The box has a new IP address | Find its MAC address on the router. On macOS, `arp -an` shows MAC addresses without leading zeros. |
| The box is not on the router either | The box did not boot NixOS | Look at its screen. It can be at the BIOS boot menu or on the USB stick. |

For the reasons behind these steps, see [About the homelab](../explanation/homelab.md).
