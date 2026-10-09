# Basics

## Layout

```text
flake.nix              inputs and outputs
overlay.nix            selects the source of each package
pkgs/                  packages that nixpkgs does not have, or has in an old version
home/                  home-manager configuration for all machines
hosts/mac/             nix-darwin, and home-manager settings for the Mac only
hosts/work-wsl/        NixOS-WSL
hosts/lab-N/           one homelab box
modules/server.nix     settings for all homelab boxes
secrets/               sops-encrypted secrets
bootstrap.sh           sets up a new Mac
```

## Flake outputs

| Output | Contents |
| --- | --- |
| `darwinConfigurations.mac` | All Apple Silicon Macs, user `josh` |
| `nixosConfigurations.work-wsl` | NixOS-WSL, user `nixos` |
| `nixosConfigurations.lab-N` | One per name in `labs`. nixos-anywhere installs these. |
| `colmenaHive` | One node per name in `labs`. colmena deploys these. |
| `overlays.default` | `overlay.nix`. devenv projects can use it. |
| `packages.<system>.*` | The packages in `pkgs/` |
| `checks` | The same as `packages`, for `nix flake check` |

nixpkgs comes from `nixos-26.05`, with `nixpkgs-26.05-darwin` for nix-darwin. Command-line
tools come from `nixpkgs-unstable` through the overlay.

## Apply

| Machine | Command |
| --- | --- |
| Mac | `rebuild` |
| NixOS-WSL | `sudo nixos-rebuild switch --flake ~/.nix-config#work-wsl` |
| All homelab boxes | `colmena apply` |
| One homelab box | `colmena apply --on lab-2` |

## Update

1. Update all inputs, or one input:

   ```sh
   nix flake update
   nix flake update nixpkgs
   ```

2. Optional: see what changes on the Mac:

   ```sh
   nix store diff-closures /run/current-system $(nix build --no-link --print-out-paths .#darwinConfigurations.mac.system)
   ```

3. Apply on each machine.

If an update breaks something, restore the lock file and apply again:

```sh
jj restore --from <change> flake.lock
```

Then update the inputs one at a time.

## Roll back

| Machine | Command |
| --- | --- |
| Mac | `rebuild --rollback` |
| NixOS-WSL | `sudo nixos-rebuild switch --rollback` |
| Homelab box | `ssh lab-1 sudo nixos-rebuild switch --rollback`, or select an older generation in the boot menu |

> **Caution:** On the Mac, a rollback removes Homebrew apps that the older generation does not
> declare. This includes 1Password.

## Update a package in pkgs/

1. Change the version.
2. Set the hash to `lib.fakeHash`.
3. Build the package, for example `nix build .#atuin`.
4. Copy the correct hash from the error message into the file.

`pkgs/cf/default.nix` has its own update steps at the top of the file.

## Clean up

```sh
nix store gc
sudo nix-collect-garbage --delete-older-than 30d
```

## GitHub token

Nix downloads inputs from GitHub. Without a token, GitHub allows 60 requests an hour. Run
`gh auth login` once on each machine. Each switch then copies the gh token to
`~/.config/nix/access-tokens.conf`.

## Look at a value

```sh
nix repl
```

```text
:lf .
darwinConfigurations.mac.config.home-manager.users.josh.programs.git.settings.user.email
```

Press Tab to see the names at each level.

## Option documentation

| Options | Where |
| --- | --- |
| NixOS | [search.nixos.org/options](https://search.nixos.org/options) |
| home-manager | [home-manager-options.extranix.com](https://home-manager-options.extranix.com) |
| nix-darwin | [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/index.html) |
| devenv | [devenv.sh/reference/options](https://devenv.sh/reference/options/) |

To learn Nix, see [nix.dev](https://nix.dev) and [Zero to Nix](https://zero-to-nix.com).

## Problems

| Problem | Cause | Action |
| --- | --- | --- |
| `path … does not exist` for a new file | jj did not record the file yet | Run `jj status` |
| `git commit` makes an empty commit | jj recorded the change first | Use `jj describe` and `jj new`. Remove the empty commit with `jj abandon`. |
| Flake inputs fail to download with a rate limit | Nix has no GitHub token | Run `gh auth login`, then apply |
| `gh config set` fails with a read-only file | home-manager controls `~/.config/gh/config.yml` | Set it in `programs.gh.settings` |
| home-manager stops and names a `.bak` file | An old backup is in the way | Move the old `.bak` file |
| A pasted command ignores its last flags | A blank line in the paste ended the command | Paste long commands as one line |
| `infinite recursion encountered` | A module reads `config` to decide what to define, often in `imports` | Put the condition in `lib.mkIf` on the value |
| An agent's commands do not have the project tools | direnv did not load | Ask the agent to run `echo $DEVENV_ROOT`. See the hooks in `home/cli.nix`. |
