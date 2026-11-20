# The Mac mini: the account vars.user, and micro-hunter's services.
{ config, pkgs, vars, ... }: {
  # micro-hunter's Reddit proxy and the Cloudflare Tunnel that the Worker reaches it through.
  # Boot services that run as vars.user, so a restart brings them back without a login. node
  # comes from Nix; cloudflared from Homebrew (brews below), so it stays current. The script and
  # its secrets (proxy.env, cookie.txt, tunnel-token) are still files in this directory.
  launchd.daemons =
    let
      dir = "${config.users.users.${vars.user}.home}/Library/Application Support/micro-hunter";
      service = log: args: {
        serviceConfig = {
          ProgramArguments = args;
          UserName = vars.user;
          GroupName = "staff";
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 10;
          StandardOutPath = "${dir}/${log}.log";
          StandardErrorPath = "${dir}/${log}.log";
        };
      };
    in
    {
      micro-hunter-reddit = service "proxy" [ "${pkgs.nodejs}/bin/node" "${dir}/reddit.mjs" ];
      micro-hunter-tunnel = service "tunnel" [
        "${config.homebrew.prefix}/bin/cloudflared" "tunnel" "--no-autoupdate" "run" "--token-file" "${dir}/tunnel-token"
      ];
    };

  homebrew.brews = [
    "cloudflared" # the micro-hunter tunnel above; Cloudflare supports a release for about a year
  ];
}
