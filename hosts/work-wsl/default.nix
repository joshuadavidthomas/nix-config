{ pkgs, ... }: {
  wsl.enable = true;
  wsl.defaultUser = "josh"; # renaming it on an installed system needs `nixos-rebuild boot` and a restart (docs/new-wsl.md)
  wsl.interop.register = true;   # re-register the binfmt handler so Windows .exe files run

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [ pkgs.git ];

  programs.fish.enable = true;

  programs.nix-ld.enable = true; # lets VS Code's WSL server and other prebuilt binaries run

  # security.pki.certificateFiles = [ ./corp-root-ca.pem ]; # if the network inspects TLS
  # work-only settings (work git email, proxies) live here, never in home/josh.nix

  home-manager.users.josh = {
    home.packages = [ pkgs.wsl-open ];
    programs.neovim.extraPackages = [ pkgs.gcc ]; # cc for tree-sitter parsers; the Mac uses Xcode's
    home.sessionVariables.BROWSER = "wsl-open";
    programs.gh.settings.browser = "wsl-open";
    programs.git = {
      settings = {
        user.email = "jthomas@westervelt.com";
        core.sshCommand = "ssh.exe";
      };
      signing.signer = "/mnt/c/Users/jthomas/AppData/Local/Microsoft/WindowsApps/op-ssh-sign.exe";
    };
    programs.jujutsu.settings.user.email = "jthomas@westervelt.com";
    home.shellAliases = {
      ssh = "ssh.exe";
      ssh-add = "ssh-add.exe";
    };
  };

  users.users.josh.shell = pkgs.fish;

  # copy the value from /etc/nixos/configuration.nix; never bump it
  system.stateVersion = "26.05";
}
