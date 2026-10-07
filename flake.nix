{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = { nixpkgs, nixos-wsl, home-manager, ... }: {
    nixosConfigurations.work-wsl = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-wsl.nixosModules.default
        ./hosts/work-wsl
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true; # reuse the system's pkgs
          home-manager.useUserPackages = true;
          home-manager.users.nixos = import ./home/josh.nix;
        }
      ];
    };
  };
}
