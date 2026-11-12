{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-3";

  # yonderd, as on lab-1 (see hosts/lab-1): the module, and the binaries yonder's
  # tests/lab/deploy.sh puts in /var/lib/yonder-bin, with the version pinned in flake.lock
  # as the fallback.
  services.yonder.enable = true;
  services.yonder.localBinaries = true;
  # A member of the yonder fabric, coordinated by yonder's coordinator on Cloudflare, with
  # this box's own tokens in a file placed by hand (see hosts/lab-1 and docs/yonder.md).
  services.yonder.coordinatorUrl = "https://yonder.joshthomas.dev";
  services.yonder.environmentFile = "/etc/yonder/coordinator.env";
  # Machines may reserve two vCPUs per host CPU; memory and disk are never overcommitted.
  services.yonder.cpuOvercommit = 2;
  # Machine disks are served from the block store over NBD (yonder's E2B-format disks)
  # instead of loop files: the module loads nbd with nbds_max=0 max_part=0 and adds the
  # udev rules. Outside yonder's state and run directories, which VMs mount read-only.
  services.yonder.servedDir = "/var/lib/yonder-served";
  # The OCI image cache is capped at 10% of the state filesystem (yonderd's
  # -disk-headroom-percent); this box's is 234 GiB, so the default 32 GiB is refused.
  # Warm slots (yonder wiki/designs/suspend-with-memory.md, step 2): an orb's memory, saved at
  # a pause and kept past its destroy for a resume here, takes at most 18 GiB of host disk,
  # evicted oldest first before anything is refused. lab-3 only, for step 2's kill tests.
  services.yonder.extraFlags = [ "-image-cache-gib" "20" "-slot-cap-gib" "18" ];
}
