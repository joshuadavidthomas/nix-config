# Docs

The docs follow [Diátaxis](https://diataxis.fr): tutorials for learning by doing, how-to
guides for getting a specific job done, reference for looking things up, and explanation for
understanding why things are the way they are.

## Tutorials

- [First steps with Nix](tutorials/first-steps.md): run tools without installing them, look
  inside the store, change the Mac's config and roll it back

## How-to guides

- [Set up a new Mac](how-to/set-up-a-mac.md)
- [Set up NixOS-WSL on a Windows laptop](how-to/set-up-nixos-wsl.md)
- [Install a homelab box](how-to/install-a-lab-box.md)
- [Move a project from mise to devenv](how-to/move-a-project-to-devenv.md)
- [Add or change a secret](how-to/manage-secrets.md)
- [Apply, update and roll back](how-to/apply-update-roll-back.md)

## Reference

- [Repo layout and flake outputs](reference/repo.md)
- [Commands](reference/commands.md)
- [Nix syntax](reference/nix-syntax.md)
- [Troubleshooting](reference/troubleshooting.md), by symptom

## Explanation

- [About Nix](explanation/nix.md): the layers called "Nix", generations, and how modules merge
- [About this repo's design](explanation/design.md): the principles behind it
- [About secrets](explanation/secrets.md): 1Password, sops and the age key
- [About coding agents and direnv](explanation/agents.md)
- [About the homelab](explanation/homelab.md)
- [How the move to Nix went](explanation/history.md): the original plan and what each phase
  turned into

The [roadmap](roadmap.md) tracks what's done and what's still open.
