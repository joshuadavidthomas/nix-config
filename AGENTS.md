# Agents

- Use jj, not git. Record a change with `jj describe -m "…"`, then `jj new`.
- After you add a file, run `jj status`.
- Run `nix flake check` before you record a change.
- Keep secrets out of `.nix` files.
- Never change `stateVersion`.
- Do not apply a change unless the owner asks. Give the owner the command.
- Do not edit `flake.lock` or `secrets/` unless the owner asks.
- When you change `bootstrap.sh`, `flake.nix`, `lib/`, `vars.nix`, `hosts/`, `modules/` or an activation step,
  update `README.md` and `docs/` in the same change.
