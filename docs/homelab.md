# Homelab

The lab boxes are NixOS machines named `lab-1`, `lab-2`, … . Everything they share is in
`modules/server.nix`; each box adds a hostname, its disk and its generated hardware config in
`hosts/lab-N/`. The Mac controls them: it installs a box with nixos-anywhere and deploys to it
with colmena. All builds run on the boxes, so the Mac needs no Linux builder.

## Install a new box

You need the box on wired ethernet, a USB stick with the NixOS minimal ISO, and the Mac with
`rebuild` already run (it installs `colmena` and the SSH settings for `lab-*`).

1. **Add it to the repo.** Copy an existing host and change the hostname:

   ```sh
   cp -r hosts/lab-1 hosts/lab-2
   echo '{ }' > hosts/lab-2/hardware-configuration.nix   # nixos-anywhere overwrites it
   ```

   In `hosts/lab-2/default.nix`, set `networking.hostName = "lab-2";`. In `flake.nix`, add
   `"lab-2"` to `labs`.

2. **Prepare the box.** In the BIOS, turn on UEFI and turn off Secure Boot. Boot the USB
   stick, then on the box's console:

   ```sh
   passwd        # any password; it only lives until the installer reboots
   ip a          # the box's IP
   lsblk         # the disk to install on, e.g. nvme0n1
   ```

   Put the disk in `hosts/lab-2/disk.nix` as `device = "/dev/nvme0n1";`. **disko erases that
   whole disk.**

3. **Install.** From `~/.nix-config` on the Mac, as one line (a blank line inside a
   multi-line paste ends the command early and silently drops the flags after it):

   ```sh
   nix run github:nix-community/nixos-anywhere -- --flake .#lab-2 --target-host nixos@<ip> --ssh-option IdentityAgent=none --generate-hardware-config nixos-generate-config ./hosts/lab-2/hardware-configuration.nix --build-on remote
   ```

   It asks for the installer password, partitions the disk, builds the system on the box,
   installs it and reboots. It ends with `Connection refused` and `### Done! ###`; that's the
   reboot, not an error.

4. **Join Tailscale.** The installed system can come back on a **different IP** than the
   installer had (see [Troubleshooting](#the-box-doesnt-come-back-after-the-install)). Find
   it, then log it in to Tailscale:

   ```sh
   ssh -o IdentitiesOnly=yes -i ~/.ssh/lab.pub josh@<new-ip> sudo tailscale up
   ```

   Open the URL it prints and approve the box. From then on it's `lab-2` everywhere:
   `ssh lab-2` works from the Mac.

5. **Record it.** Describe the change in jj so the generated `hardware-configuration.nix` goes
   in with it:

   ```sh
   jj describe -m "Add lab-2" && jj new
   ```

6. **Check it.** Deploy once with `colmena apply --on lab-2`. It should finish with
   `Activation successful`.

## Day to day

```sh
colmena apply                # deploy every box
colmena apply --on lab-2     # just one
ssh lab-1 nixos-version      # what a box is running
```

To roll back, reboot the box and pick an older generation in the boot menu, or deploy an
older revision of this repo.

## How it fits together

- **`nixosConfigurations.lab-N`** is what nixos-anywhere installs.
- **`colmenaHive`** is what colmena deploys. Each node imports the module list of its
  `nixosConfigurations` entry, so the two always build the same system. Don't give the hive
  its own module list: nixpkgs adds things inside `nixosSystem` that a bare list misses, such
  as the version label (without it the box calls itself `26.05pre-git`).
- **SSH keys.** The boxes trust one key, the "Mac mini" key in 1Password, for both `josh` and
  `root` (colmena deploys as root). `hosts/mac/home.nix` writes its public half to
  `~/.ssh/lab.pub` and tells SSH to offer only that key to `lab-*`. The private key never
  leaves 1Password.

## Troubleshooting

### `Too many authentication failures`, or `Connection reset by peer`

1Password's agent holds more keys than sshd accepts (it gives up after 6), and SSH offers
every agent key before trying a password. After enough failures, sshd starts dropping new
connections from the Mac for several minutes. That shows up as
`kex_exchange_identification: read: Connection reset by peer`, even though the box answers
pings.

- To clear the block now, run `sudo systemctl restart sshd` on the box's console.
- To avoid it with the installer, use `--ssh-option IdentityAgent=none` as in step 3.
- For an installed box, connect by name (`ssh lab-2`), or with
  `-o IdentitiesOnly=yes -i ~/.ssh/lab.pub` when you only have an IP.

### nixos-anywhere keeps asking for `root@…` password

Don't pass `--ssh-option PubkeyAuthentication=no`. After the first login, nixos-anywhere puts
its own temporary key on the installer and switches to root with it. With key logins off, it
falls back to asking for root's password, which the installer doesn't have. Press Ctrl-C and
use `IdentityAgent=none` instead. Nothing has been written to the disk at that point.

### The box doesn't come back after the install

If the old IP stops answering, the box most likely asked the router for an address
differently and got a new one (lab-1 went from 10.0.0.80 to 10.0.0.81). Find it by the network
card's MAC address, which doesn't change. Note it while the installer is up:

```sh
arp -an | grep '(<ip>)'    # on the Mac, after you've connected to the installer
```

Then look for that MAC in your router's list of DHCP clients, or in `arp -an` on the Mac.
macOS prints MACs without leading zeros (`0:2b:67:35:6:d5`, not `00:2b:67:35:06:d5`).

The installed system has no password login, so you can't sign in on its console to check. If
the MAC doesn't turn up, look at the box's screen: it may be at the BIOS boot menu, or booting
the USB stick again.

### `git commit` made an empty commit

This repo is managed by jj, which records the working copy into the current change
automatically. A `git commit` gets imported, but it comes out empty if jj had already
recorded the files. Use `jj describe -m "…"` and `jj new` instead; `jj abandon <change>`
removes an empty one.
