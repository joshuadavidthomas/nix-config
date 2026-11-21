# Builds every machine in flake.nix: NixOS (WSL, the lab boxes, VMs) or nix-darwin (the Mac).
# Each gets the overlay, the base module for its OS in modules/, the secrets from 1Password,
# and home-manager for vars.user with home/. hosts/<name>/default.nix adds the rest, including
# its own home.nix; a Mac can do without one. `user` replaces vars.user for one machine: a Mac
# whose account has another name.
# Modules get the configuration's name as `configName`, for `rebuild`, and the machine's name
# on the tailnet as `tailnetName`: the configuration's name, unless the machine sets another.
{ self, inputs, vars }:
name: { system, user ? vars.user, tailnetName ? name }:
let
  inherit (inputs.nixpkgs) lib;
  vars' = vars // { inherit user; };
  os = if lib.hasSuffix "-darwin" system then "darwin" else "nixos";
  systemFunc = if os == "darwin" then inputs.nix-darwin.lib.darwinSystem else lib.nixosSystem;
in
systemFunc {
  specialArgs = { inherit inputs tailnetName; vars = vars'; configName = name; };
  modules = [
    {
      nixpkgs.hostPlatform = system;
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [ self.overlays.default ];
      # the commit this was built from, or its dirty tree: nixos-version
      # --configuration-revision, darwin-version --configuration-revision
      system.configurationRevision = self.rev or self.dirtyRev or null;
    }
    ../modules/${os}
    inputs.opnix."${os}Modules".default
    ../modules/secrets.nix
  ] ++ lib.optional (builtins.pathExists ../hosts/${name}/default.nix) ../hosts/${name} ++ [
    inputs.home-manager."${os}Modules".home-manager
    {
      home-manager.useGlobalPkgs = true; # reuse the system's pkgs
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = { inherit inputs tailnetName; vars = vars'; configName = name; };
      home-manager.users.${user}.imports = [ ../home ];
    }
  ];
}
