# Identity is shared; each host sets user.email and signing.signer.
{ vars, ... }: {
  programs.git = {
    enable = true;
    settings.user.name = vars.name;
    signing = {
      format = "ssh";
      key = vars.keys.signing;
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
  };
}
