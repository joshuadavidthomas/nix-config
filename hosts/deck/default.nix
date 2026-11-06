# The Steam Deck. SteamOS owns the operating system and updates itself (A/B images), so this
# is a plain home-manager module, built as homeConfigurations.deck. The user is SteamOS's own
# `deck` (uid 1000), not `josh`: the Steam session and Valve's update tooling expect it.
# One hard rule: the login shell stays bash, and fish is started by hand. SteamOS updates
# reset /etc/shells, and a login shell that is not in it keeps both the desktop session and
# SSH from logging in (SteamOS issue #2922).
{
  home.username = "deck";
  home.homeDirectory = "/home/deck";

  # home-manager's own module for a machine where Nix does not manage the OS: it fills in
  # XDG paths and such, the same way it does on WSL.
  targets.genericLinux.enable = true;
}
