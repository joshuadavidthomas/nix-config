{ pkgs, ... }: {
  wsl.enable = true;
  wsl.defaultUser = "nixos"; # renaming the WSL user takes extra steps; see the NixOS-WSL docs
  wsl.interop.register = true;   # re-register the binfmt handler so Windows .exe files run

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [ pkgs.git ];

  programs.fish.enable = true;

  programs.nix-ld.enable = true; # lets VS Code's WSL server and other prebuilt binaries run

  # security.pki.certificateFiles = [ ./corp-root-ca.pem ]; # if the network inspects TLS
  # work-only settings (work git email, proxies) live here, never in home/josh.nix

  home-manager.users.nixos = {
    home.packages = [ pkgs.wsl-open ];
    home.sessionVariables.BROWSER = "wsl-open";
    programs.gh.settings.browser = "wsl-open";
    programs.git.settings = {
      user.email = "jthomas@westervelt.com";
      core.sshCommand = "ssh.exe";
      gpg.format = "ssh";
      gpg.ssh.program = "/mnt/c/Users/jthomas/AppData/Local/Microsoft/WindowsApps/op-ssh-sign.exe";
      user.signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu+mS88ARLvrHMl3CshOJRL/Ft3TJRr/dG+hTq39aNW";
      commit.gpgsign = true;
    };
    home.shellAliases = {
      ssh = "ssh.exe";
      ssh-add = "ssh-add.exe";
    };
  };

  users.users.nixos.shell = pkgs.fish;

  # copy the value from /etc/nixos/configuration.nix; never bump it
  system.stateVersion = "26.05";
}
