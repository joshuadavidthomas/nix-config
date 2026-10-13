{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-3";

  # yonderd, as on lab-1 (see hosts/lab-1): the module, and the binaries yonder's
  # tests/lab/deploy.sh puts in /var/lib/yonder/bin, with the version pinned in flake.lock
  # as the fallback.
  services.yonder.enable = true;
  services.yonder.localBinaries = true;
  # A member of the yonder fabric (yonder M3), coordinated by yonder-coordinator: a Fly
  # Machine on the tailnet that is not a host, since a host that coordinates others can
  # always reach itself while cut off (yonder.dev wiki/designs/coordinator-runtime.md).
  # -join is a flag rather than the module's join option until flake.lock moves past M3.
  services.yonder.extraFlags = [ "-join" "yonder-coordinator" ];
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
