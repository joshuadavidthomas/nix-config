# Repo layout and flake outputs

## Layout

```text
.
├── flake.nix              # inputs and outputs
├── flake.lock             # pinned inputs
├── overlay.nix            # overlays.default: where each package comes from
├── pkgs/                  # packages missing from nixpkgs, or newer than it has
│   ├── atuin.nix          # atuin 18.23.0, an override of the nixpkgs recipe
│   ├── cf/                # Cloudflare CLI, from its npm package
│   ├── lisette.nix        # from release binaries
│   └── llm/               # llm and plugins, built with uv2nix from uv.lock
├── home/                  # home-manager config shared by every machine
│   ├── josh.nix           # entry point: packages, PATH, shells
│   ├── agents.nix         # coding agents, their config and hooks
│   ├── cli.nix            # atuin, bat, btop, direnv, eza, fzf, tmux, …
│   ├── fish.nix
│   ├── git.nix            # git, gh, jj
│   ├── neovim.nix
│   ├── nix.nix            # Nix user config, gh token for fetches, ~/.nix-config clone
│   ├── secrets.nix        # age key from 1Password, atuin login
│   ├── dotfiles/          # files shipped as-is (starship.toml)
│   └── files/             # scripts and plugins
├── hosts/
│   ├── mac/               # nix-darwin (default.nix) and Mac-only home-manager (home.nix)
│   ├── work-wsl/          # NixOS-WSL
│   └── lab-N/             # default.nix, disk.nix (disko), hardware-configuration.nix
├── modules/
│   └── server.nix         # shared by every homelab box
├── secrets/               # sops-encrypted; recipients in .sops.yaml
├── .sops.yaml
├── bootstrap.sh           # sets up a fresh Mac
└── docs/
```

## Flake outputs

| Output | Contents |
| --- | --- |
| `overlays.default` | `overlay.nix`; also usable from a project's devenv |
| `packages.<system>.{atuin,cf,lisette,llm}` | The packages in `pkgs/`, for `aarch64-darwin` and `x86_64-linux` |
| `checks` | Same as `packages`, so `nix flake check` builds them |
| `darwinConfigurations.mac` | Any Apple Silicon Mac, user `josh` |
| `nixosConfigurations.work-wsl` | NixOS-WSL, user `nixos` |
| `nixosConfigurations.lab-N` | One per name in `labs`; what nixos-anywhere installs |
| `colmenaHive` | One node per name in `labs`; what colmena deploys |

## Flake inputs

| Input | Branch or pin | Used for |
| --- | --- | --- |
| `nixpkgs` | `nixos-26.05` | NixOS hosts, home-manager, runtimes and libraries |
| `nixpkgs-darwin` | `nixpkgs-26.05-darwin` | nix-darwin |
| `nixpkgs-unstable` | `nixpkgs-unstable` | Standalone CLI tools, through the overlay |
| `nixos-wsl` | `main` | The WSL host |
| `nix-darwin` | `nix-darwin-26.05` | The Mac |
| `home-manager` | `release-26.05` | Every machine |
| `nix-homebrew` | latest, with `brew-src` pinned to 7.0.9 | Installs and pins Homebrew on the Mac |
| `disko` | latest | Disk layout for homelab installs |
| `colmena` | latest | Homelab deploys; the `colmena` CLI on the Mac |
| `pyproject-nix`, `uv2nix`, `pyproject-build-systems` | latest | Building `pkgs/llm` from `uv.lock` |
| `tokyonight` | fork, not a flake | Theme files for bat, btop, eza, ghostty, posting, wezterm |

## Machines

| Machine | Host config | User | Applied with |
| --- | --- | --- | --- |
| Apple Silicon Mac | `hosts/mac` | `josh` | `rebuild` |
| Work laptop | `hosts/work-wsl` | `nixos` | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| Homelab box | `hosts/lab-N`, `modules/server.nix` | `josh`, `root` | `colmena apply` |
