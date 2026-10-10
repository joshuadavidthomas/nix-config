# Values that more than one machine uses. lib/mksystem.nix passes them to every module as
# `vars`.
{
  user = "josh";
  name = "Josh Thomas";
  email = "josh@joshthomas.dev";

  # where colmena and `rebuild` read the opnix service account token (modules/secrets.nix)
  opnixToken = "op://Private/Service Account Auth Token: dotfiles/credential";

  # public halves of keys kept in 1Password
  keys = {
    # "Mac mini": the lab boxes trust it for SSH, and colmena deploys with it
    controller = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVCdVXgBfljpv3nqraSApsBRM7Lg5U/L8HIXTNXesBn";
    # "github.com": signs commits
    signing = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu+mS88ARLvrHMl3CshOJRL/Ft3TJRr/dG+hTq39aNW";
  };
}
