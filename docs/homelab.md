# Homelab

The homelab boxes are `lab-1`, `lab-2` and so on. They share `modules/server.nix`. Each box
has a directory in `hosts/` with its hostname, disk layout and hardware configuration.

nixos-anywhere installs a box from the Mac. colmena deploys changes from the Mac. The builds
run on the boxes, so the Mac does not need a Linux builder.

## SSH access

The boxes accept one SSH key, the "Mac mini" key in 1Password, for `josh` and `root`. colmena
deploys as `root`.

The 1Password agent has more keys than sshd accepts. sshd stops after six tries, and after
more failures it blocks the Mac for some minutes. So `hosts/mac/home.nix` tells SSH to use
only `~/.ssh/lab.pub` for `lab-*`.

After the install, the Mac connects to each box by its name through Tailscale.

## Install a box

The examples use `lab-2`. You need the box on ethernet and a USB stick with the NixOS minimal
ISO.

1. Copy an existing host:

   ```sh
   cp -r hosts/lab-1 hosts/lab-2
   echo '{ }' > hosts/lab-2/hardware-configuration.nix
   jj status
   ```

2. In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`.
3. In `flake.nix`, add `"lab-2"` to `labs`.
4. In the BIOS of the box, turn on UEFI. Turn off Secure Boot.
5. Boot the box from the USB stick.
6. On the box, set a password for the installer:

   ```sh
   passwd
   ```

7. On the box, get the IP address, the MAC address and the disk name:

   ```sh
   ip a
   lsblk
   ```

8. In `hosts/lab-2/disk.nix`, set the disk, for example `device = "/dev/nvme0n1";`.

   > **Warning:** The install erases this disk.

9. On the Mac, in `~/.nix-config`, run this command as one line:

   ```sh
   nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --build-on remote
   ```

10. Enter the installer password when asked.

    The command installs NixOS and reboots the box. It ends with `Connection refused` and
    `### Done! ###`. This is the reboot, not an error.

11. Find the new IP address of the box. It can be different from the installer address. Look
    for the MAC address in the DHCP client list on the router.
12. Start Tailscale on the box:

    ```sh
    ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> sudo tailscale up
    ```

13. Open the URL that the command prints. Approve the box.
14. Record the change and deploy:

    ```sh
    jj describe -m "Add lab-2" && jj new
    colmena apply --on lab-2
    ```

    The deploy ends with `Activation successful`.

> **Note:** `IdentityAgent=none` stops SSH from trying the 1Password keys, so the installer
> asks for the password. Do not use `PubkeyAuthentication=no`. nixos-anywhere adds a
> temporary key and then connects as `root` with it. If key logins are off, it asks for a
> `root` password, and the installer has none.

## Deploy, check and roll back

| Task | Command |
| --- | --- |
| Deploy to all boxes | `colmena apply` |
| Deploy to one box | `colmena apply --on lab-2` |
| Show the version on a box | `ssh lab-1 nixos-version` |
| Roll back a box | `ssh lab-1 sudo nixos-rebuild switch --rollback` |

If SSH does not work, reboot the box and select an older generation in the boot menu.

## Problems

| Problem | Cause | Action |
| --- | --- | --- |
| `Too many authentication failures`, or `Connection reset by peer` while ping works | sshd blocks the Mac after too many failed keys | On the box, run `sudo systemctl restart sshd`. Make sure that the command has `--ssh-option IdentityAgent=none`. |
| nixos-anywhere asks for a `root@…` password again and again | The command has `--ssh-option PubkeyAuthentication=no` | Press Ctrl-C. Use `--ssh-option IdentityAgent=none`. The disk is not changed yet. |
| The box does not answer after the install | The box has a new IP address | Find its MAC address on the router. On macOS, `arp -an` shows MAC addresses without leading zeros. |
| The box is not on the router | The box did not boot NixOS | Look at its screen. It can be at the BIOS boot menu or on the USB stick. |
