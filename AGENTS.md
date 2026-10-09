# Agents

- Read `README.md` first. Follow its rules.
- Do not apply a change unless the owner asks. `rebuild` and `nixos-rebuild` need sudo, so give
  the owner the command.
- Do not edit `flake.lock` or `secrets/` unless the owner asks.
- When a change touches `bootstrap.sh`, the outputs in `flake.nix`, `hosts/`, `modules/` or an
  activation step, search `README.md` and `docs/` for the file or step name. Update what you
  find in the same change.
