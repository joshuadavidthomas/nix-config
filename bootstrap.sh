#!/bin/sh
# Fresh Mac to fully configured, no arguments:
#
#   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh
#
# Any Apple Silicon Mac gets the same `mac` configuration. Safe to rerun; each step skips
# what's already done.
#
#   1. Install Determinate Nix.
#   2. Ask for the 1Password service account token and put it in /etc/opnix-token.
#   3. Switch straight from GitHub. That installs Homebrew, every app and tool, and clones
#      this repo to ~/.nix-config. opnix starts to fetch the secrets (atuin, fonts, ...).
#   4. Wait for opnix, then switch again from ~/.nix-config, so that the steps that use the
#      secrets (atuin's login) run.
set -eu

flake=github:joshuadavidthomas/nix-config
config=mac
token=/etc/opnix-token
# the first secret that modules/secrets.nix writes on a Mac
secret="$HOME/Library/Application Support/opnix/atuinPassword"

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

# 2. The service account token: the only secret put on a machine by hand. Read from the
# terminal, not stdin, which is this script when it's piped from curl.
if ! sudo test -s "$token"; then
  say "Paste the token from the 1Password item \"Service Account Auth Token: dotfiles\" (Private vault), then press Enter"
  stty -echo < /dev/tty
  read -r value < /dev/tty
  stty echo < /dev/tty
  printf '%s\n' "$value" | sudo sh -c "umask 077; cat > $token"
fi

# 3. First switch, from GitHub. darwin-rebuild comes from the nix-darwin this repo pins.
if [ ! -x /run/current-system/sw/bin/darwin-rebuild ]; then
  say "First switch, straight from GitHub"
  sudo -H nix run --inputs-from "$flake" nix-darwin#darwin-rebuild -- switch --flake "$flake#$config"
fi

# 4. opnix runs as a launchd service, beside the switch. Wait for it, then switch again.
if [ ! -e "$secret" ]; then
  say "Waiting for opnix to fetch the secrets from 1Password"
  # on a rerun the service may have run before the token was there
  sudo launchctl kickstart -k system/org.nixos.opnix-secrets 2>/dev/null || true
  tries=0
  until [ -e "$secret" ]; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then
      echo "opnix fetched nothing in 2 minutes; see /var/log/opnix-secrets.log" >&2
      exit 1
    fi
    sleep 2
  done
fi

say "Switching again from ~/.nix-config"
sudo -H /run/current-system/sw/bin/darwin-rebuild switch --flake "$HOME/.nix-config#$config"

say "Done. Sign in to 1Password and turn on its SSH agent. Open a new terminal; from now on, \`rebuild\` applies changes."
