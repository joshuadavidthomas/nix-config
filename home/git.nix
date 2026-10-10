# Identity is shared. The Mac and WSL sign commits with the 1Password key through
# 1Password's signer. The lab boxes sign with their shared key (modules/nixos/server.nix).
# The work laptop sets its own email.
{ lib, vars, ... }: {
  programs.git = {
    enable = true;
    settings.user.name = vars.name;
    settings.user.email = lib.mkDefault vars.email;
    signing = {
      format = "ssh";
      key = lib.mkDefault vars.keys.signing;
      signByDefault = true;
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      aliases.co = "pr checkout";
    };
    gitCredentialHelper.enable = true; # git over HTTPS to github.com uses gh's token
  };

  programs.jujutsu = {
    enable = true;
    settings.user.name = vars.name;
    settings.user.email = lib.mkDefault vars.email;
  };
}
