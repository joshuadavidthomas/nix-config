# Identity is shared; each host sets user.email and signing.signer.
{ pkgs, ... }: {
  programs.git = {
    enable = true;
    settings.user.name = "Josh Thomas";
    # 1Password "github.com" key
    signing = {
      format = "ssh";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu+mS88ARLvrHMl3CshOJRL/Ft3TJRr/dG+hTq39aNW";
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
    settings.user.name = "Josh Thomas";
  };
}
