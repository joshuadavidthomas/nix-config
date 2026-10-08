#!/bin/sh
# Fresh Mac to fully configured, no arguments:
#
#   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
#
# Any Apple Silicon Mac gets the same `mac` configuration. Safe to rerun; each step skips
# what's already done.
#
#   1. Install Determinate Nix.
#   2. Switch straight from GitHub. That installs Homebrew, every app (1Password included)
#      and tool, and clones this repo to ~/.nix-config. Secret-backed steps wait.
#   3. Wait for you to sign in to 1Password and turn on its CLI integration.
#   4. Switch again from ~/.nix-config: the age key comes from 1Password and every secret
#      (atuin, fonts, ...) falls into place.
set -eu

flake=github:joshuadavidthomas/nix-config
config=mac
op=/usr/local/bin/op

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [ "$(uname -s)" != Darwin ]; then
  echo "bootstrap.sh handles Macs; Linux machines are installed from a Mac with nixos-anywhere." >&2
  exit 1
fi
if [ "$(uname -m)" != arm64 ]; then
  echo "This config targets Apple Silicon; several of its packages no longer build for Intel Macs." >&2
  exit 1
fi

# 1. Nix
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  say "Installing Determinate Nix"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi
PATH=/nix/var/nix/profiles/default/bin:$PATH
export PATH

# 2. First switch, from GitHub. darwin-rebuild comes from the nix-darwin this repo pins.
if [ ! -x /run/current-system/sw/bin/darwin-rebuild ]; then
  say "First switch, straight from GitHub"
  sudo -H nix run --inputs-from "$flake" nix-darwin#darwin-rebuild -- switch --flake "$flake#$config"
fi

# 3. 1Password. `op whoami` only reports state; listing vaults is what makes 1Password ask
# you to approve the CLI (Touch ID), so wait on that.
if ! "$op" vault list >/dev/null 2>&1; then
  say "Sign in to 1Password, turn on Settings > Developer > Integrate with 1Password CLI, then approve the prompt"
  open -a 1Password || true
  printf 'Waiting for 1Password'
  until "$op" vault list >/dev/null 2>&1; do
    printf '.'
    sleep 5
  done
  echo
fi

# 4. Second switch, from the local clone, now that secrets can unlock.
say "Switching again from ~/.nix-config"
sudo -H /run/current-system/sw/bin/darwin-rebuild switch --flake "$HOME/.nix-config#$config"

say "Done. Open a new terminal; from now on, \`rebuild\` applies changes."
