# Every NixOS machine: WSL, the lab boxes and VMs.
{ lib, pkgs, vars, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.fish.enable = true;
  users.users.${vars.user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
  };

  # home-manager's switch reads secrets that opnix writes (atuin's login), so it waits for opnix
  systemd.services."home-manager-${vars.user}" = {
    wants = [ "opnix-secrets.service" ];
    after = [ "opnix-secrets.service" ];
  };

  # opnix retries a failed fetch after 15 minutes, at most twice an hour. At boot its first
  # fetch can fail while DNS is still coming up, even after network-online: on lab-1 it did
  # at every boot, and with resolvconf all three of its quick retries failed too, so every
  # secret arrived 15 minutes late. Retry within seconds instead.
  systemd.services.opnix-secrets = {
    serviceConfig.RestartSec = lib.mkForce "10s";
    unitConfig.StartLimitBurst = lib.mkForce 5;
  };

  # prebuilt Linux binaries need a standard dynamic loader: the coding agents' installers,
  # uv's Python builds, VS Code's WSL server
  programs.nix-ld.enable = true;

  environment.systemPackages = [ pkgs.git ];

  # eMudhra intermediate CA keys were compromised in October 2026
  # (https://emudhra.we-have-a-problem.com/). Browsers block the intermediates through
  # revocation, but curl, git and anything else that reads the system bundle does not. Distrust
  # the roots they chain to until nixpkgs ships cacert 3.131.1 or later, then remove this.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
}
