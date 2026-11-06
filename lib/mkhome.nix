# Builds the machines whose operating system is not Nix: the Steam Deck (SteamOS, hosts/deck).
# Same overlay and shared home/ as every machine, but as standalone home-manager, applied on
# the machine with home-manager switch --flake github:joshuadavidthomas/nix-config#deck.
# There is no NixOS module layer: what modules/ does for a NixOS machine is SteamOS's job,
# or a deliberate, tested integration on the host (modules/nixos owns nothing here).
{ self, inputs, vars }:
name: { system }:
let
  # nixpkgs.hostPlatform is a NixOS setting; a standalone home-manager builds pkgs itself.
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ self.overlays.default ];
  };
in
inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  extraSpecialArgs = {
    inherit inputs vars;
    # in the NixOS machines, home-manager's bridge passes the machine config as osConfig;
    # a standalone configuration has no machine behind it, so it is null (home/atuin.nix).
    osConfig = null;
  };
  modules = [
    ../hosts/${name}
    ../home
  ];
}
