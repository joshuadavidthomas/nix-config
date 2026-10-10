# Builds every machine in flake.nix: NixOS (WSL, the lab boxes, VMs) or nix-darwin (the Mac).
# Each gets the overlay, the base module for its OS in modules/, the secrets from 1Password,
# and home-manager for vars.user with home/. hosts/<name> adds the rest, including its own
# home.nix.
{ self, inputs, vars }:
name: { system }:
let
  inherit (inputs.nixpkgs) lib;
  os = if lib.hasSuffix "-darwin" system then "darwin" else "nixos";
  systemFunc = if os == "darwin" then inputs.nix-darwin.lib.darwinSystem else lib.nixosSystem;
in
systemFunc {
  specialArgs = { inherit inputs vars; };
  modules = [
    {
      nixpkgs.hostPlatform = system;
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ self.overlays.default ];
    }
    ../modules/${os}
    inputs.opnix."${os}Modules".default
    ../modules/secrets.nix
    ../hosts/${name}
    inputs.home-manager."${os}Modules".home-manager
    {
      home-manager.useGlobalPkgs = true; # reuse the system's pkgs
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = { inherit inputs vars; };
      home-manager.users.${vars.user}.imports = [ ../home ];
    }
  ];
}
