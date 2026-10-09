{ inputs, vars, ... }: {
  imports = [ inputs.nixos-wsl.nixosModules.default ];

  wsl.enable = true;
  wsl.defaultUser = vars.user; # renaming it on an installed system needs `nixos-rebuild boot` and a restart (docs/new-wsl.md)
  wsl.interop.register = true;   # re-register the binfmt handler so Windows .exe files run

  programs.nix-ld.enable = true; # lets VS Code's WSL server and other prebuilt binaries run

  # security.pki.certificateFiles = [ ./corp-root-ca.pem ]; # if the network inspects TLS

  home-manager.users.${vars.user}.imports = [ ./home.nix ];

  # copy the value from /etc/nixos/configuration.nix; never bump it
  system.stateVersion = "26.05";
}
