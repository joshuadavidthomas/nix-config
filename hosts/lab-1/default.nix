{ inputs, ... }: {
  imports = [
    ../../modules/nixos/server.nix
    ../../modules/nixos/single-disk.nix
    ./hardware-configuration.nix # written by nixos-anywhere at install
    inputs.yonder.nixosModules.default
  ];

  networking.hostName = "lab-1";

  # yonderd, so a reboot, a reinstall or `rebuild` brings it back. The module also
  # runs the .internal resolver in its own units (yonder-resolver.socket and .service, as
  # the user yonder-resolver) and guests' calls to their host in yonder-connect.service (as
  # the user yonder-connect, which yonderd reaches through /run/yonder/connect), enables
  # systemd-resolved (.internal on the box), turns off SNAT on Tailscale subnet routes,
  # accepts the other boxes' routes, opens the resolver (port 53) to the tailnet and to
  # guests, and keeps dhcpcd off yonder's interfaces. The fabric API (tcp 7086) is no longer
  # open. The daemon advertises its own guest routes; tag:lab's are approved by the tailnet
  # policy (tailscale-acls).
  services.yonder.enable = true;
  # lab-1 is where yonder is developed: its yonderd runs what yonder's tests/lab/deploy.sh
  # puts in /var/lib/yonder-bin, and the version pinned in flake.lock when nothing is there
  # (`deploy.sh revert`). So shipping yonder work in progress needs no change here; bump
  # the lock only to move that fallback, or when yonder's module changes.
  services.yonder.localBinaries = true;
  # A member of the yonder fabric, coordinated by yonder's coordinator on Cloudflare (a
  # Durable Object), which each box dials out to. lab-1 coordinated until 2026-10-13, and
  # a Fly Machine on the tailnet until 2026-10-16 (docs/yonder.md).
  services.yonder.coordinatorUrl = "https://yonder.joshthomas.dev";
  # The coordinator's token and this box's own Cloudflare Access service token. Placed by
  # hand, root 0600, outside the store (docs/yonder.md); not in /etc/yonder/secrets.env,
  # which yonderd delivers to every guest.
  services.yonder.environmentFile = "/etc/yonder/coordinator.env";
  # Machines may reserve two vCPUs per host CPU; memory and disk are never overcommitted.
  services.yonder.cpuOvercommit = 2;
}
