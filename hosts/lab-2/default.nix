{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-2";

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
}
