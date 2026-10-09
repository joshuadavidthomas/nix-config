# Nix syntax

The constructs that cover nearly every config in this repo.

```nix
# Attribute set (a dict). Dotted keys nest:
{ programs.git.enable = true; }        # same as { programs = { git = { enable = true; }; }; }

# List: space-separated, no commas
[ pkgs.ripgrep pkgs.fd pkgs.jq ]

# let … in: local bindings
let user = "josh"; in { users.users.${user}.isNormalUser = true; }

# Function: one argument, `arg: body`. A module takes an attribute set:
{ config, pkgs, lib, ... }: { environment.systemPackages = [ pkgs.htop ]; }

# Strings, interpolation, multi-line strings (common indentation stripped)
"hello ${user}"
''
  echo "multi-line"
''

# inherit: shorthand for `user = user;`
{ inherit user; }

# with: bring a set's names into scope (fine for package lists, avoid elsewhere)
with pkgs; [ ripgrep fd ]

# Paths: their own type, copied into the store when used
imports = [ ./hardware-configuration.nix ];

# Merging two sets (right side wins)
{ a = 1; } // { b = 2; }

# Conditionals
if pkgs.stdenv.isDarwin then "mac" else "linux"
```

## Module helpers

| Helper | Does |
| --- | --- |
| `lib.mkIf cond value` | Defines `value` only when `cond` is true |
| `lib.optionalAttrs cond set` | `set` when `cond` is true, otherwise `{ }`; use it for attribute sets such as `env` |
| `lib.mkDefault value` | A weaker definition that any other module overrides |
| `lib.mkForce value` | A stronger definition that overrides other modules |
| `lib.mkAfter list` | Puts a list's items after other modules' items |
| `lib.getExe pkg` | The path to a package's main program |
| `lib.genAttrs names f` | `{ name = f name; … }` for each name in a list |

## Where options are documented

| Option set | Where |
| --- | --- |
| NixOS | [search.nixos.org/options](https://search.nixos.org/options) |
| home-manager | [home-manager-options.extranix.com](https://home-manager-options.extranix.com) |
| nix-darwin | [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/index.html) |
| devenv | [devenv.sh/reference/options](https://devenv.sh/reference/options/) |
| This flake | `nix repl`, `:lf .`, then tab-complete, e.g. `nixosConfigurations.lab-1.config.` |
