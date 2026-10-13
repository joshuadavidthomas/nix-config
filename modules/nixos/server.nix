# Everything the homelab boxes have in common. Each hosts/lab-N adds its hostname, disk
# and generated hardware config.
{ config, pkgs, vars, ... }: {
  nix.settings.trusted-users = [ "root" vars.user ];
  nix.gc = { automatic = true; options = "--delete-older-than 30d"; };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true; # NIC firmware and CPU microcode

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };
  users.users.${vars.user}.openssh.authorizedKeys.keys = [ vars.keys.controller ];
  users.users.root.openssh.authorizedKeys.keys = [ vars.keys.controller ]; # colmena deploys as root
  security.sudo.wheelNeedsPassword = false;

  # Amp orbs log in as orb, over Tailscale SSH (docs/orbs.md). Agents' files stay out of josh's
  # and root's homes, and each root command goes through sudo, so the journal records it. Not
  # a boundary: wheel has passwordless sudo here.
  users.users.orb = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # Commits on the lab boxes are signed with one shared key from 1Password (docs/decisions.md).
  services.onepassword-secrets.secrets.gitSigningKey = {
    reference = "op://dotfiles/Lab signing key/private key?ssh-format=openssh";
    owner = vars.user;
    group = "users";
  };
  home-manager.users.${vars.user}.programs.git.signing.key =
    config.services.onepassword-secrets.secretPaths.gitSigningKey;

  # A new lab box joins the tailnet on its first boot, tagged lab, with the secret of a
  # Tailscale OAuth client (docs/new-lab-box.md). tailscaled-autoconnect logs in only when the
  # box is logged out, so a box that is already on the tailnet keeps its node.
  services.onepassword-secrets.secrets.tailscaleAuthKey.reference =
    "op://dotfiles/Homelab Tailscale OAuth/client secret";
  services.tailscale = {
    enable = true;
    authKeyFile = config.services.onepassword-secrets.secretPaths.tailscaleAuthKey;
    # keys from an OAuth client are ephemeral unless told otherwise
    authKeyParameters = { ephemeral = false; preauthorized = true; };
    extraUpFlags = [ "--advertise-tags=tag:lab" ];
    # Tailscale SSH: the tailnet policy (tailscale-acls) decides who logs in as whom, so
    # Amp orbs reach the box with no keys to manage. Set on every apply, not only at login.
    extraSetFlags = [ "--ssh" ];
  };
  systemd.services.tailscaled-autoconnect = {
    wants = [ "opnix-secrets.service" ];
    after = [ "opnix-secrets.service" ];
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Monitoring (docs/research/homelab-monitoring.md). The exporters listen on localhost only:
  # tailscale0 is trusted, so on 0.0.0.0 every tailnet node could read them. Vector scrapes
  # them and reads the journal. Until the Fly machine exists, nothing leaves the box: metrics
  # go to a local preview, logs are dropped.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    enabledCollectors = [ "systemd" ]; # unit states, in place of container metrics
  };
  services.prometheus.exporters.smartctl = {
    enable = true; # drive health; scans every disk
    listenAddress = "127.0.0.1";
  };
  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      sources.exporters = {
        type = "prometheus_scrape";
        endpoints = map (e: "http://127.0.0.1:${toString e.port}/metrics")
          (with config.services.prometheus.exporters; [ node smartctl ]);
        scrape_interval_secs = 30;
      };
      sources.journal.type = "journald";
      sources.vector.type = "internal_metrics"; # shows the journal's volume in the preview
      transforms.metrics = {
        type = "remap";
        inputs = [ "exporters" ];
        source = ''.tags.host = "${config.networking.hostName}"'';
      };
      # What would be shipped: curl 127.0.0.1:9598/metrics. Shipping replaces these two sinks.
      sinks.preview = {
        type = "prometheus_exporter";
        inputs = [ "metrics" "vector" ];
        address = "127.0.0.1:9598";
      };
      sinks.logs = {
        type = "blackhole";
        inputs = [ "journal" ];
        print_interval_secs = 0;
      };
    };
  };

  environment.systemPackages = [ pkgs.htop ];

  system.stateVersion = "26.05"; # set at install; never bump it
}
