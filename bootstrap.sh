#!/bin/sh
# Fresh Mac to fully configured. The argument is the Mac's name in the repo (hosts/<name>),
# such as mac-mini. A name that is not in the repo yet adds the Mac to it.
#
#   curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh -s -- <name>
#
# Safe to rerun; each step skips what's already done.
#
#   1. Install Determinate Nix.
#   2. Install Homebrew with its own installer; after that it updates itself.
#   3. Log in to GitHub with gh. Nix fetches private inputs (yonder) with its token.
#   4. Clone this repo to ~/.nix-config.
#   5. A new Mac: write hosts/<name>/mac.json, with this account.
#   6. Before the first switch: record in mac.json the apps that are already on this Mac and
#      that a cask also installs, such as the ones an employer's IT installed. Homebrew leaves
#      them alone on this Mac (modules/darwin).
#   7. First switch, from the clone. That installs every app (1Password included) and tool.
#      Secret-backed steps wait.
#   8. Wait for you to sign in to 1Password and turn on its CLI integration.
#   9. Copy the opnix token from 1Password to /etc/opnix-token, and wait for opnix to fetch
#      the secrets (atuin, fonts, ...).
#  10. Switch again, so that the steps that use the secrets (atuin's login) run.
#  11. Wait for you to turn on 1Password's SSH agent. If steps 5 or 6 changed hosts/<name>,
#      commit it (signed, as every commit is) and push.
set -eu

repo=https://github.com/joshuadavidthomas/nix-config
flake=github:joshuadavidthomas/nix-config
dir=$HOME/.nix-config
name=${1:-}
op=/usr/local/bin/op
token=/etc/opnix-token
# the first secret that modules/secrets.nix writes on a Mac
secret="$HOME/Library/Application Support/opnix/atuinPassword"
agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

case "$name" in
  "" | *[!a-z0-9-]*)
    echo "Give the Mac a name of lowercase letters, digits and '-', such as mac-mini:" >&2
    echo "  curl -fsSL https://raw.githubusercontent.com/joshuadavidthomas/nix-config/main/bootstrap.sh | sh -s -- <name>" >&2
    exit 1
    ;;
esac
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

# 2. Homebrew. Its installer won't prompt for the password when NONINTERACTIVE is set, so
# cache sudo first.
if [ ! -x /opt/homebrew/bin/brew ]; then
  say "Installing Homebrew"
  sudo -v
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_AUTO_UPDATE

# 3. GitHub. gh, git and jq run from the nixpkgs this repo pins; the first switch installs
# gh and git for good. gh's token stays in the keychain, where that gh finds it. Each Nix
# command below, and root's under sudo, gets the token in NIX_CONFIG: root doesn't read your
# Nix config.
gh() { nix run --inputs-from "$flake" nixpkgs-darwin#gh -- "$@"; }
git() { nix run --inputs-from "$flake" nixpkgs-darwin#git -- "$@"; }
jq() { nix run --inputs-from "$flake" nixpkgs-darwin#jq -- "$@"; }
if ! gh auth token >/dev/null 2>&1; then
  say "Log in to GitHub"
  # the script itself is sh's stdin; git_protocol is ssh, as in home/git.nix
  gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --web </dev/tty
fi
NIX_CONFIG="access-tokens = github.com=$(gh auth token)"
export NIX_CONFIG

# 4. The repo. Every switch, the first one too, runs from this clone.
if [ ! -d "$dir/.git" ]; then
  say "Cloning the repo to ~/.nix-config"
  git clone "$repo" "$dir"
fi
host="$dir/hosts/$name"
json="$host/mac.json"

# 5. The Mac in the repo. Nix sees only the files that git tracks, so each change is added.
if [ ! -e "$json" ]; then
  if [ -e "$host" ]; then
    echo "hosts/$name is not a Mac. Give this Mac another name." >&2
    exit 1
  fi
  say "Adding $name to the repo, for the account $(id -un)"
  mkdir -p "$host"
  printf '{\n  "user": "%s"\n}\n' "$(id -un)" > "$json"
  git -C "$dir" add "hosts/$name/mac.json"
fi
user=$(jq -r .user "$json")
if [ "$user" != "$(id -un)" ]; then
  echo "hosts/$name is for the account $user, but you are logged in as $(id -un)." >&2
  exit 1
fi

# 6. Apps that are on this Mac already, from IT or by hand, and that a cask also installs.
# Homebrew would take them over, so mac.json lists them in preinstalledCasks, and Homebrew
# leaves them alone. Only before the first switch can this tell: after it, the apps in
# /Applications are Homebrew's own.
if [ ! -x /run/current-system/sw/bin/darwin-rebuild ]; then
  say "Looking for apps that are already on this Mac"
  # brew info sees a third-party tap's casks only once it is tapped
  for tap in $(nix eval --raw "$dir#darwinConfigurations.$name.config.homebrew.taps" --apply 'ts: toString (map (t: t.name) ts)'); do
    /opt/homebrew/bin/brew tap "$tap" >/dev/null
  done
  casks=$(nix eval --raw "$dir#darwinConfigurations.$name.config.homebrew.casks" --apply 'cs: toString (map (c: c.name) cs)')
  ours=$(/opt/homebrew/bin/brew list --cask -1 2>/dev/null || true)
  receipts=$(pkgutil --pkgs)
  found=
  list=$(mktemp)
  # one line per cask: token;app|app;pkg|pkg
  # shellcheck disable=SC2086 # one word per cask
  /opt/homebrew/bin/brew info --cask --json=v2 $casks |
    jq -r '.casks[] | [.token,
      ([.artifacts[] | .app? // empty | .[] | strings | split("/") | last] | join("|")),
      ([.artifacts[] | .uninstall? // empty | .[] | .pkgutil? // empty] | flatten | join("|"))] | join(";")' \
    > "$list"
  while IFS=';' read -r token apps pkgs; do
    printf '%s\n' "$ours" | grep -qx "$token" && continue
    hit=
    IFS='|'
    for app in $apps; do
      if [ -e "/Applications/$app" ]; then hit=1; fi
    done
    for pkg in $pkgs; do
      if printf '%s\n' "$receipts" | grep -qx "$pkg"; then hit=1; fi
    done
    unset IFS
    [ -n "$hit" ] || continue
    # the name in casks, with its tap if it has one
    for cask in $casks; do
      if [ "${cask##*/}" = "$token" ]; then found="$found $cask"; fi
    done
  done < "$list"
  rm -f "$list"
  if [ -n "$found" ]; then
    say "Homebrew leaves these apps alone on this Mac:$found"
    # shellcheck disable=SC2086 # one word per cask
    jq --args '.preinstalledCasks = ((.preinstalledCasks // []) + $ARGS.positional | unique)' $found < "$json" > "$json.new"
    mv "$json.new" "$json"
    git -C "$dir" add "hosts/$name/mac.json"
  fi
fi

# 7. First switch. darwin-rebuild comes from the nix-darwin this repo pins.
if [ ! -x /run/current-system/sw/bin/darwin-rebuild ]; then
  say "First switch"
  sudo -H --preserve-env=NIX_CONFIG nix run --inputs-from "$flake" nix-darwin#darwin-rebuild -- switch --flake "$dir#$name"
fi

# 8. 1Password. `op whoami` only reports state; listing vaults is what makes 1Password ask
# you to approve the CLI (Touch ID), so wait on that.
if ! sudo test -s "$token" && ! "$op" vault list >/dev/null 2>&1; then
  say "Sign in to 1Password, turn on Settings > Developer > Integrate with 1Password CLI, then approve the prompt"
  open -a 1Password || true
  printf 'Waiting for 1Password'
  until "$op" vault list >/dev/null 2>&1; do
    printf '.'
    sleep 5
  done
  echo
fi

# 9. The opnix token. opnix runs as a launchd service, beside the switch, so wait for it.
if ! sudo test -s "$token"; then
  say "Copying the opnix token from 1Password"
  # vars.opnixTokenArgs
  value=$("$op" item get "Service Account Auth Token: dotfiles" --vault Private --fields credential --reveal)
  printf '%s\n' "$value" | sudo sh -c "umask 077; cat > $token"
fi
if [ ! -e "$secret" ]; then
  say "Waiting for opnix to fetch the secrets from 1Password"
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

# 10. Second switch, now that the secrets are there.
say "Switching again"
sudo -H --preserve-env=NIX_CONFIG /run/current-system/sw/bin/darwin-rebuild switch --flake "$dir#$name"

# 11. 1Password's SSH agent: SSH and commit signing use it. Then commit and push what steps 5
# and 6 wrote. The commit is signed with the 1Password key (home/git.nix); the push goes over
# HTTPS with gh's token.
if ! SSH_AUTH_SOCK="$agent" ssh-add -l >/dev/null 2>&1; then
  say "Turn on 1Password's Settings > Developer > Use the SSH agent"
  printf 'Waiting for the SSH agent'
  until SSH_AUTH_SOCK="$agent" ssh-add -l >/dev/null 2>&1; do
    printf '.'
    sleep 5
  done
  echo
fi
if [ -n "$(git -C "$dir" status --porcelain -- "hosts/$name")" ]; then
  say "Committing and pushing hosts/$name"
  git -C "$dir" commit -m "hosts/$name: the Mac's account and the apps that were on it before Homebrew" -- "hosts/$name"
  if ! { git -C "$dir" pull --rebase && git -C "$dir" push; }; then
    echo "The push failed. hosts/$name is committed in ~/.nix-config; push it from there." >&2
    exit 1
  fi
fi

say "Done. Open a new terminal; from now on, \`rebuild\` applies changes."
