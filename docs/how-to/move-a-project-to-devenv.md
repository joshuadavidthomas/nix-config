# How to move a project from mise to devenv

This procedure replaces `mise.toml`, setup scripts and docker-compose with devenv. This repo
installs devenv and direnv on each machine.

## Create the environment

1. In the project, run:

   ```sh
   devenv init
   ```

   This writes `devenv.nix`, `devenv.yaml`, `.envrc` and `.gitignore` entries.

2. Let direnv load the environment:

   ```sh
   direnv allow
   ```

## Copy the configuration from mise

Put each mise setting in `devenv.nix`:

| mise | devenv |
| --- | --- |
| `[tools] python = "3.13"` | `languages.python.enable = true;` and `languages.python.version = "3.13";` |
| `[env]` | `env.NAME = "…";` |
| `[tasks]` | `scripts.<name>.exec` or `tasks."app:<name>".exec` |
| docker-compose Postgres or Redis | `services.postgres`, `services.redis` |
| `.pre-commit-config.yaml` | `git-hooks.hooks.*` |

Put the checks of the project in `enterTest`. `devenv test` runs them.

For a variable on one platform only, use `lib.optionalAttrs`:

```nix
env = { RUST_LOG = "info"; } // lib.optionalAttrs pkgs.stdenv.isLinux { LD_LIBRARY_PATH = "…"; };
```

Do not use `lib.mkIf` for this. On the other platform, it fails with
`The option 'env.LD_LIBRARY_PATH' was accessed but has no value defined`.

To use the package versions of this repo, add the repo as an input and apply its overlay:

```yaml
# devenv.yaml
inputs:
  nix-config:
    url: github:joshuadavidthomas/nix-config
```

```nix
# devenv.nix
{ inputs, ... }: { overlays = [ inputs.nix-config.overlays.default ]; }
```

## Test the environment

1. Run the checks:

   ```sh
   devenv test
   ```

2. If the project runs on macOS and Linux, test on both.
3. Ask an agent to run `echo $DEVENV_ROOT` in the project. The output must be the project
   path. If it is empty, the agent does not get the environment.

If the compiler crashes with `dyld: Symbol not found` on macOS, a tool sets
`DYLD_LIBRARY_PATH`. Unset the variable for that tool.

## Move CI

In GitHub Actions, use these steps:

```yaml
- uses: cachix/install-nix-action@v31
- uses: nix-community/cache-nix-action@v7
  with:
    primary-key: devenv-${{ runner.os }}-${{ runner.arch }}-${{ hashFiles('devenv.nix', 'devenv.yaml', 'devenv.lock') }}
    restore-prefixes-first-match: devenv-${{ runner.os }}-${{ runner.arch }}-
- uses: cachix/cachix-action@v17
  with:
    name: devenv
- run: nix profile add nixpkgs#devenv
- run: devenv test
```

CI is slower with devenv than with mise and a toolchain cache.

Do not build release binaries with Nix. They refer to `/nix/store` and do not run on other
machines.

## Remove mise

Use devenv daily for one or two weeks. Then delete `mise.toml`.
