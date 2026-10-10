# Values that more than one machine uses. lib/mksystem.nix passes them to every module as
# `vars`.
{
  user = "josh";
  name = "Josh Thomas";
  email = "josh@joshthomas.dev";

  # `op` arguments that print the opnix service account token, for `rebuild` and bootstrap.sh
  # (modules/secrets.nix). Not `op read`: secret references can't contain the title's ':'.
  opnixTokenArgs = [ "item" "get" "Service Account Auth Token: dotfiles" "--vault" "Private" "--fields" "credential" "--reveal" ];

  # public halves of keys kept in 1Password
  keys = {
    # "Mac mini": the lab boxes trust it for SSH, and colmena deploys with it
    controller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVCdVXgBfljpv3nqraSApsBRM7Lg5U/L8HIXTNXesBn";
    # "github.com": signs commits
    signing = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu+mS88ARLvrHMl3CshOJRL/Ft3TJRr/dG+hTq39aNW";
  };
}
