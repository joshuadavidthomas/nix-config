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
  # as the fallback.
  services.yonder.enable = true;
  services.yonder.localBinaries = true;
  # A member of lab-1's fabric (yonder M3): it registers with lab-1, the coordinator,
  # over the tailnet, and machines are placed on it from any box. -join is a flag rather
  # than the module's join option until flake.lock moves past yonder M3.
  services.yonder.extraFlags = [ "-join" "lab-1" ];
  # Each box reaches the others' guests through their routes (yonder's module sets these
  # too, from M3 on).
  services.tailscale.useRoutingFeatures = "both";
  services.tailscale.extraSetFlags = [ "--accept-routes" ];
  # Guests ask the .internal resolver on this box through their TAPs (yonder M3); the
  # firewall refuses unknown interfaces otherwise. yonder's own table drops everything
  # else a guest sends the box. yonder's module does this too, from M3 on.
  networking.firewall.extraCommands = ''
    iptables -I nixos-fw -i yt-+ -p udp --dport 53 -j nixos-fw-accept
    iptables -I nixos-fw -i yt-+ -p tcp --dport 53 -j nixos-fw-accept
  '';
}
