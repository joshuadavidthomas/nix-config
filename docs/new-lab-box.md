# Set up a lab box

The examples use `lab-2`. Use the next free number.

## What you need

- The lab box, connected to ethernet
- A USB stick with the NixOS minimal ISO
- The Mac, with the configuration applied
- The Tailscale OAuth client in 1Password. See [The Tailscale client](secrets.md#the-tailscale-client).

## Add the lab box to the repo

1. On the Mac, in `~/.nix-config`, copy a lab box:

   ```sh
   cp -r hosts/lab-1 hosts/lab-2
   ```

2. Empty the hardware configuration:

   ```sh
   echo '{ }' > hosts/lab-2/hardware-configuration.nix
   ```

3. Track the new files. Nix sees only the files that version control tracks.

4. In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`.
5. In `flake.nix`, add `"lab-2"` to `labs`.
6. If you install the lab box again, remove the old `lab-2` in the
   [Tailscale admin console](https://login.tailscale.com/admin/machines). If you do not, the
   lab box joins as `lab-2-1`.

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
2. Copy the opnix token to a folder for the install. nixos-anywhere puts the folder's files
   on the lab box.

   ```sh
   mkdir -p /tmp/lab-2/etc && install -m 600 /etc/opnix-token /tmp/lab-2/etc/opnix-token
   ```

3. Run nixos-anywhere. Paste the command as one line.

   ```sh
   nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --extra-files /tmp/lab-2 --build-on remote
   ```

4. Enter the installer password when asked. The output ends with `Connection refused` and
   `### Done! ###`. That is the restart.
5. Remove the copy of the token:

   ```sh
   rm -r /tmp/lab-2
   ```

## Connect to Tailscale

The lab box joins Tailscale by itself when it starts: opnix reads the Tailscale client from
1Password, and the lab box joins as `lab-2`, with the tag `lab`. This takes about a minute.

Connect by name. The output shows the NixOS version.

```sh
ssh lab-2 nixos-version
```

## Apply

```sh
colmena apply --on lab-2
```

colmena copies the Mac's opnix token to the lab box. The output ends with
`Activation successful`.

## If it stops

| What you see | Cause | Action |
| --- | --- | --- |
| `Too many authentication failures` | SSH offered too many 1Password keys | Use `--ssh-option IdentityAgent=none` for the installer. Use `-o IdentitiesOnly=yes -i ~/.ssh/lab.pub` for an installed lab box. |
| `kex_exchange_identification: read: Connection reset by peer`, but ping works | sshd blocks the Mac after many failed logins | On the lab box, run `sudo systemctl restart sshd` |
| nixos-anywhere asks for the `root@…` password again and again | The command has `PubkeyAuthentication=no` | Press Ctrl-C. Use `IdentityAgent=none`. The disk is not changed yet. |
| The lab box does not answer after the install | The IP address changed | Find the MAC address on the router. On macOS, `arp -an` shows MAC addresses without leading zeros. |
| The lab box is not on the router | NixOS did not start | Look at the screen. The lab box can be in the BIOS boot menu or on the USB stick. |
| `ssh lab-2` does not find the lab box | The lab box did not join Tailscale | Find the IP address on the router. Run `ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> journalctl -u opnix-secrets -u tailscaled-autoconnect`. |
| `Token file /etc/opnix-token does not exist` in that log | The install did not get the token | Run `ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> 'sudo tee /etc/opnix-token >/dev/null && sudo systemctl restart opnix-secrets tailscaled-autoconnect' < /etc/opnix-token` |
| `requested tags [tag:lab] are invalid or not permitted` | The OAuth client does not have the tag `lab` | Make the client again. See [The Tailscale client](secrets.md#the-tailscale-client). |
| The lab box is `lab-2-1` in Tailscale | An old `lab-2` is in the tailnet | Remove the old `lab-2` in the admin console. Then rename the new one to `lab-2` there. |
