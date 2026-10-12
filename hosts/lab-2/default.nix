{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-2";

  # yonderd, as on lab-1 (see hosts/lab-1): the module, and the binaries yonder's
  # tests/lab/deploy.sh puts in /var/lib/yonder/bin, with the version pinned in flake.lock
  # as the fallback. yonder M3 adds this box to lab-1's fabric; until that code is deployed
  # here, yonderd runs on its own, with no machines.
  services.yonder.enable = true;
  services.yonder.localBinaries = true;
  # Until M3's code is deployed here, this box announces no routes on the tailnet. Every
  # box announces the shared .internal resolver address, and Tailscale may pick any of them
  # to answer for the whole tailnet; on 2026-10-12 it picked lab-2, which knows none of
  # lab-1's machines, and dev.internal stopped resolving from the Mac. M3 makes every box
  # answer for every machine; then this line goes.
  services.yonder.extraFlags = [ "-tailscale" "" ];
}
