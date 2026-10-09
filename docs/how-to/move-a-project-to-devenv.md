# How to move a project from mise to devenv

This replaces a project's `mise.toml` (and any setup scripts or docker-compose for local
services) with devenv. devenv and direnv are already installed on every machine by this repo.

## Create the environment

In the project:

```sh
devenv init
```

That writes `devenv.nix`, `devenv.yaml`, `.envrc` (which loads devenv through direnv) and
`.gitignore` entries. Allow direnv once:

```sh
direnv allow
```

## Port the mise config

Translate `mise.toml` into `devenv.nix`:

| In mise | In devenv |
| --- | --- |
| `[tools] python = "3.13"` | `languages.python.enable = true; languages.python.version = "3.13";` |
| `[env]` | `env.NAME = "…";` |
| `[tasks]` | `scripts.<name>.exec` or `tasks."app:<name>".exec` |
| docker-compose Postgres/Redis | `services.postgres`, `services.redis` |
| `.pre-commit-config.yaml` | `git-hooks.hooks.*` |

Put the project's checks in `enterTest`, so `devenv test` runs them.

If a variable only applies on one platform, merge it in with `lib.optionalAttrs`:

```nix
env = { RUST_LOG = "info"; } // lib.optionalAttrs pkgs.stdenv.isLinux { LD_LIBRARY_PATH = "…"; };
```

Wrapping it in `lib.mkIf` instead fails with `The option 'env.LD_LIBRARY_PATH' was accessed
but has no value defined` on the other platform.

If you want this repo's package versions in the project, add it as an input and apply its
overlay:

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

## Check it

```sh
devenv test
```

Build on both the Mac and Linux if the project runs on both. The first run on a second
platform can turn up real bugs that the other platform's CI never hit.

If a tool in the environment sets `DYLD_LIBRARY_PATH` on macOS and the compiler then crashes
with `dyld: Symbol not found`, unset the variable around that tool. Nix's clang honors it,
while Apple's `cc` ignores it.

Agents get the environment too: the non-interactive direnv hooks from this repo load it into
their tool calls. To confirm, ask an agent to run `echo $DEVENV_ROOT` in the project.

## Move CI

In GitHub Actions, install Nix, restore the Nix store from cache, and run devenv:

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

Expect CI to run slower than mise with a toolchain cache, even with the store cached. Keep
release builds off Nix: Nix-built binaries reference `/nix/store` and won't run elsewhere.

## Remove mise

Leave `mise.toml` in place until devenv has been the daily driver for a week or two, then
delete it.
