{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs-darwin";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    colmena.url = "github:nix-community/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # the Homebrew release nix-homebrew installs; its own pin trails upstream
    nix-homebrew.inputs.brew-src.url = "github:Homebrew/brew/7.0.9";

    # builds Python apps from a uv.lock (pkgs/llm)
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs-unstable";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";
    pyproject-build-systems.inputs.pyproject-nix.follows = "pyproject-nix";
    pyproject-build-systems.inputs.uv2nix.follows = "uv2nix";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs-unstable";

    # source of every tokyonight theme file (bat, btop, eza, ghostty, posting, wezterm)
    tokyonight.url = "github:joshuadavidthomas/tokyonight.nvim";
    tokyonight.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, nixos-wsl, nix-darwin, home-manager, nix-homebrew, disko, colmena, ... }:
    let
      nixpkgsConfig = {
        nixpkgs.config.allowUnfree = true;
        nixpkgs.overlays = [ self.overlays.default ];
      };

      homeManagerFor = user: {
        home-manager.useGlobalPkgs = true; # reuse the system's pkgs
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "bak";
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.${user} = import ./home/josh.nix;
      };

      # the homelab boxes, by hostname; each has a hosts/<name>
      labs = [ "lab-1" "lab-2" "lab-3" ];
    in
    {
      # every machine applies this; project devenvs can reuse it:
      #   devenv.yaml: inputs.nix-config.url = "github:joshuadavidthomas/nix-config"
      #   devenv.nix:  overlays = [ inputs.nix-config.overlays.default ];
      overlays.default = import ./overlay.nix inputs;

      # `nix build .#<name>` and `nix flake check` build the packages from ./pkgs on their own
      packages = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        inherit (import nixpkgs { inherit system; config.allowUnfree = true; overlays = [ self.overlays.default ]; })
          atuin cf lisette llm;
      });
      checks = self.packages;

      nixosConfigurations = {
        work-wsl = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nixos-wsl.nixosModules.default
            nixpkgsConfig
            ./hosts/work-wsl
            home-manager.nixosModules.home-manager
            (homeManagerFor "nixos")
          ];
        };
      }
      # nixos-anywhere installs a lab box from here; colmenaHive deploys it afterwards
      // nixpkgs.lib.genAttrs labs (name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ disko.nixosModules.disko ./hosts/${name} ];
      });

      # `colmena apply` from the Mac; every build runs on the boxes themselves
      colmenaHive = colmena.lib.makeHive ({
        meta.nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        defaults = {
          deployment.buildOnTarget = true;
          # colmena's lib comes from plain `import nixpkgs`, which lacks the flake's version
          # info; without these the system calls itself 26.05pre-git
          system.nixos.versionSuffix = nixpkgs.lib.trivial.versionSuffix;
          system.nixos.revision = nixpkgs.lib.trivial.revisionWithDefault null;
        };
      } // nixpkgs.lib.genAttrs labs (name: {
        # every module nixosSystem used, including the one nixpkgs adds itself (the
        # `nixpkgs` registry pin), so colmena deploys exactly what was installed
        imports = self.nixosConfigurations.${name}._module.args.modules;
        deployment.targetHost = name; # Tailscale MagicDNS
      }));

      # any Apple Silicon Mac; bootstrap.sh and `rebuild` use this, not the hostname
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          nixpkgsConfig
          nix-homebrew.darwinModules.nix-homebrew
          ./hosts/mac
          home-manager.darwinModules.home-manager
          (homeManagerFor "josh")
        ];
      };
    };
}
