# Packages nixpkgs doesn't carry, or carries older than what's already in use.
# Built on nixpkgs-unstable by ../overlay.nix.
inputs: final: prev: {
  atuin = final.callPackage ./atuin.nix { inherit (prev) atuin; };
  cf = final.callPackage ./cf { };
  lisette = final.callPackage ./lisette.nix { };
  llm = final.callPackage ./llm { inherit inputs; };
}
