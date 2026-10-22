# Every Mac.
{ pkgs, vars, ... }: {
  nix.enable = false; # Determinate Nix manages the daemon; nix-darwin must not
  system.primaryUser = vars.user; # required for user-level options (Homebrew, defaults)
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # knownUsers lets nix-darwin set the login shell. For this existing account (uid 501)
  # activation only updates UserShell and PrimaryGroupID (20, unchanged); nix-darwin
  # refuses to delete the primary user or any uid <= 501.
  users.knownUsers = [ vars.user ];
  users.users.${vars.user} = {
    uid = 501;
    home = "/Users/${vars.user}";
    shell = pkgs.fish;
  };

  # The same eMudhra workaround as modules/nixos/default.nix; remove both together. This covers
  # the Nix bundle (NIX_SSL_CERT_FILE) that Nix-built tools read. macOS's own curl, git and
  # python3 read /etc/ssl/cert.pem, which Nix does not manage (docs/decisions.md).
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];
}
