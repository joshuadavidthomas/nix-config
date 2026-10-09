# How to install a homelab box

This installs NixOS on a new box from the Mac and joins it to the tailnet. The examples add
`lab-2`; use the next free number.

You need the box on wired ethernet, a USB stick with the NixOS minimal ISO, and a Mac set up
from this repo (it provides `colmena` and the SSH settings for `lab-*`).

## 1. Add the box to the repo

```sh
cp -r hosts/lab-1 hosts/lab-2
echo '{ }' > hosts/lab-2/hardware-configuration.nix   # nixos-anywhere overwrites it
```

In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`. In `flake.nix`, add
`"lab-2"` to `labs`.

## 2. Boot the installer

In the BIOS, turn on UEFI and turn off Secure Boot. Boot the USB stick, then on the box's
console:

```sh
passwd        # any password; it only lasts until the installer reboots
ip a          # the box's IP, and its MAC address
lsblk         # the disk to install on, e.g. nvme0n1
```

Note the MAC address as well as the IP. Put the disk in `hosts/lab-2/disk.nix` as
`device = "/dev/nvme0n1";`. disko erases that whole disk.

## 3. Install

From `~/.nix-config` on the Mac, run this as one line. A blank line inside a multi-line paste
ends the command early and drops the flags after it.

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --build-on remote
```

It asks for the installer password, partitions the disk, builds the system on the box,
installs it and reboots. The `Connection refused` just before `### Done! ###` is the reboot.

## 4. Join Tailscale

The installed system may come back on a different IP from the installer's. If the old one
doesn't answer, look up the box's MAC address in your router's DHCP client list, or in
`arp -an` on the Mac (which prints MACs without leading zeros, `0:2b:67:35:6:d5` rather than
`00:2b:67:35:06:d5`).

Then log the box in to Tailscale:

```sh
ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<ip> sudo tailscale up
```

Open the URL it prints and approve the box. After that, `ssh lab-2` works from the Mac.

## 5. Record and deploy

```sh
jj describe -m "Add lab-2" && jj new
colmena apply --on lab-2
```

The deploy should finish with `Activation successful`.

## If something goes wrong

If SSH to the installer fails with `Too many authentication failures`, or with
`Connection reset by peer` while the box still answers pings, sshd is blocking the Mac after
too many failed key attempts. Run `sudo systemctl restart sshd` on the box's console, and make
sure the install command includes `--ssh-option IdentityAgent=none`.

If nixos-anywhere keeps asking for a `root@…` password, the command has
`--ssh-option PubkeyAuthentication=no` in it. Press Ctrl-C and use `IdentityAgent=none`
instead. Nothing has been written to the disk at that point.

If the box's new IP doesn't turn up anywhere, look at its screen. It may be sitting at the
BIOS boot menu or booting the USB stick again. The installed system has no password login, so
you can't sign in at its console.

See [About the homelab](../explanation/homelab.md) for why the install works this way.
