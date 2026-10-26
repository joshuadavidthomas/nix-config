# Agents

- Read `docs/decisions.md` before you change machines, secrets or the repo structure. If it
  does not answer a question, ask the owner. Do not guess.
- Nix sees only the files that version control tracks. Track a file after you add it.
- Run `nix flake check` after every change.
- Keep secrets out of `.nix` files.
- Never change `stateVersion`.
- Do not apply a change unless the owner asks. Give the owner the command.
- Do not edit `flake.lock` unless the owner asks. There is one exception. If the owner tells the
  yonder thread to deploy a yonder change, for example "deploy it" or "deploy and run the lab
  tests", and that thread passes on his words, the owner has asked for a lab bump. He does not need
  to ask again here. A lab bump is these steps:
  - Change only the `yonder` node in `flake.lock`, to a commit on yonder.dev's `origin/main`.
  - Sign the commit with the lab key, check it with `git verify-commit`, run
    `nix flake check` and push to `main`.
  - Dry-activate on lab-1, lab-2 and lab-3, then switch them one at a time.
  - Make sure that no `yonder-vm-*` unit and no VM restarts.

  Any other `flake.lock` change, any other input, any other host and any change to the lab's
  configuration still need the owner to ask directly.
- When you change `bootstrap.sh`, `flake.nix`, `lib/`, `vars.nix`, `hosts/`, `modules/` or an activation step,
  update `README.md` and `docs/` in the same change.
