# Everything the homelab boxes have in common. Each hosts/lab-N adds its hostname, disk
# and generated hardware config.
{ config, lib, pkgs, vars, ... }:
let
  # node_exporter's collectors that Grafana shows live, scraped faster than the rest. Every
  # counter that a dashboard draws as a rate is here: a rate over Grafana's 40 s window needs a
  # sample in each window, and the slow scrape is 60 s. cpufreq is a gauge, here so the clock
  # speed on the Machine dashboard moves with its CPU.
  liveCollectors = [
    "cpu" "cpufreq" "meminfo" "loadavg" "netdev" "diskstats" "pressure" "stat" "vmstat"
    "netstat" "softnet" "schedstat"
  ];
  # node_exporter with only (collect) or all but (exclude) the live collectors
  nodeExporterUrl = param: "http://127.0.0.1:${toString config.services.prometheus.exporters.node.port}/metrics?"
    + lib.concatMapStringsSep "&" (c: "${param}%5B%5D=${c}") liveCollectors;
in
{
  nix.settings.trusted-users = [ "root" vars.user ];
  nix.gc = { automatic = true; options = "--delete-older-than 30d"; };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  hardware.enableRedistributableFirmware = true; # NIC firmware and CPU microcode

  # Swap, compressed in memory (up to half of it, zstd): when memory runs out, a build or a VM
  # slows down instead of being killed. No swap partition (modules/nixos/single-disk.nix).
  zramSwap.enable = true;

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
  # them, reads the journal, and sends both to the monitor over the tailnet (docs/monitor.md).
  # It buffers to disk, so an outage of the monitor or the ISP leaves no gap, though the queued
  # samples arrive thinned (docs/roadmap.md).
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    enabledCollectors = [ "systemd" ]; # unit states, in place of container metrics
    extraFlags = [
      # when each unit started: how long each yonder VM has been up, on the dashboards
      "--collector.systemd.enable-start-time-metrics"
      # node_cpu_info, a series per thread with its core and model: cores and threads, on the
      # dashboards
      "--collector.cpu.info"
    ];
  };
  services.prometheus.exporters.smartctl = {
    enable = true; # drive health; scans every disk
    listenAddress = "127.0.0.1";
  };
  services.vector = {
    enable = true;
    journaldAccess = true;
    settings = {
      # Two speeds, so Grafana feels live: what is watched live every 10 s (about a quarter of
      # the series), everything else every 60 s. node_exporter serves each
      # set of collectors at its own URL; the SMART exporter reads the drives each 60 s anyway.
      # tailscaled serves its client metrics (traffic direct or through a DERP relay, health
      # warnings) to the box itself at 100.100.100.100.
      sources.fast = {
        type = "prometheus_scrape";
        endpoints = [ (nodeExporterUrl "collect") ];
        scrape_interval_secs = 10;
      };
      sources.slow = {
        type = "prometheus_scrape";
        endpoints = [
          (nodeExporterUrl "exclude")
          "http://127.0.0.1:${toString config.services.prometheus.exporters.smartctl.port}/metrics"
          "http://100.100.100.100/metrics"
        ];
        scrape_interval_secs = 60;
      };
      # Each systemd unit's CPU and memory, from its cgroup, every 10 s: what is using the box,
      # each yonder VM (its unit, yonder-vm-<ID>.service) among them. Only Vector's cgroups
      # collector; node_exporter has the rest.
      sources.units = {
        type = "host_metrics";
        collectors = [ "cgroups" ];
        cgroups.levels = 3; # the root, the slices, and the units in them
        scrape_interval_secs = 10;
      };
      sources.journal.type = "journald";
      sources.vector.type = "internal_metrics";
      # The exporters' own Go runtime and HTTP handler stats; everything node_* and smartctl_*
      # stays, for the stock dashboards
      transforms.useful = {
        type = "filter";
        inputs = [ "fast" "slow" ];
        condition = ''!match(string!(.name), r'^(go|process|promhttp)_')'';
      };
      # Of Vector's own metrics, only what shows a backlog or lost events
      transforms.vectorHealth = {
        type = "filter";
        inputs = [ "vector" ];
        # inside Vector its own metrics are named without the vector_ prefix, in the namespace vector
        condition = ''.namespace == "vector" && match(string!(.name), r'^(buffer_|component_errors_total$|component_discarded_events_total$)')'';
      };
      # A unit's CPU time and the memory it holds (anon: not the file cache it could give back),
      # for each unit in a slice: system.slice/nix-daemon.service, user.slice/user-1000.slice.
      # Not the slices themselves, which would count their units twice, and not mounts or
      # sockets. Inside Vector these are named without the host_ prefix, in the namespace host.
      transforms.unitsUseful = {
        type = "filter";
        inputs = [ "units" ];
        condition = ''.namespace == "host" && includes(["cgroup_cpu_usage_seconds_total", "cgroup_memory_anon_bytes"], .name) && match(string!(.tags.cgroup), r'^[^/]+/[^/]+\.(service|scope|slice)$')'';
      };
      transforms.unitsNamed = {
        type = "remap";
        inputs = [ "unitsUseful" ];
        source = ''
          .tags.unit = replace(string!(.tags.cgroup), r'^.*/', "")
          del(.tags.collector)
        '';
      };
      transforms.metrics = {
        type = "remap";
        inputs = [ "useful" "vectorHealth" "unitsNamed" ];
        # instance and job are what the stock dashboards select by
        source = ''
          .tags.host = "${config.networking.hostName}"
          .tags.instance = .tags.host
          name = string!(.name)
          .tags.job = if .namespace == "vector" { "vector" } else if .namespace == "host" { "units" } else if starts_with(name, "smartctl_") { "smartctl" } else if starts_with(name, "tailscaled_") { "tailscale" } else { "node" }
        '';
      };
      sinks.victoriametrics = {
        type = "prometheus_remote_write";
        inputs = [ "metrics" ];
        endpoint = "http://monitor:8428/api/v1/write";
        healthcheck.enabled = false; # VictoriaMetrics answers 204, which the check counts as failure
        # about 1.5 GB a day of samples at 30 s, so a day or two of outage at two speeds
        buffer = { type = "disk"; max_size = 4 * 1024 * 1024 * 1024; when_full = "block"; };
      };
      # VictoriaLogs takes Elasticsearch's bulk API. One log stream for each box and unit.
      sinks.victorialogs = {
        type = "elasticsearch";
        inputs = [ "journal" ];
        endpoints = [ "http://monitor:9428/insert/elasticsearch/" ];
        mode = "bulk";
        api_version = "v8";
        healthcheck.enabled = false;
        query = {
          _msg_field = "message";
          _time_field = "timestamp";
          _stream_fields = "host,_SYSTEMD_UNIT";
        };
        buffer = { type = "disk"; max_size = 1024 * 1024 * 1024; when_full = "block"; };
      };
      # What this box sends, and Vector's own metrics: curl 127.0.0.1:9598/metrics
      sinks.preview = {
        type = "prometheus_exporter";
        inputs = [ "metrics" "vector" ];
        address = "127.0.0.1:9598";
      };
    };
  };

  environment.systemPackages = [ pkgs.htop ];

  system.stateVersion = "26.05"; # set at install; never bump it
}
