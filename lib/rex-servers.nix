# Every Rex server on the tailnet (docs/rex.md): the lab boxes, the Steam Deck and the Macs.
# Rex for Mac's host list (modules/darwin/rex.nix) and the CLI's host labels (home/cli.nix)
# come from this list, so a new lab box or Mac shows up on every machine at its next switch.
#
# Each server is { name, url, icon, id }. name is the machine's name on the tailnet. icon is
# an SF Symbol. id is Rex for Mac's record id: the first four are the ids that the app gave
# them, so its records stay the same ones; every other id comes from the name.
lib: vars:
let
  hosts = builtins.readDir ../hosts;
  macs = lib.filterAttrs
    (dir: type: type == "directory" && builtins.pathExists ../hosts/${dir}/mac.json)
    hosts;

  ids = {
    lab-1 = "043146D3-9A9C-483D-B914-C49878E127D5";
    lab-2 = "A5336183-E25A-4415-9539-3780DA0CBE19";
    lab-3 = "6CA718F4-E90C-403B-9701-E9EDDD3D92B4";
    steamdeck = "FE35619C-F872-4330-82C2-42D24D022620";
  };
  uuid = name:
    let h = lib.toUpper (builtins.hashString "sha256" "rex-server:${name}"); in
    "${lib.substring 0 8 h}-${lib.substring 8 4 h}-${lib.substring 12 4 h}-${lib.substring 16 4 h}-${lib.substring 20 12 h}";

  server = name: url: icon: { inherit name url icon; id = ids.${name} or (uuid name); };
in
# The lab boxes and the Deck serve Rex through Tailscale Serve on Rex's port, 7297.
map (name: server name "https://${name}.${vars.tailnet}:7297" "server.rack") vars.labs
++ [ (server "steamdeck" "https://steamdeck.${vars.tailnet}:7297" "desktopcomputer") ]
# A Mac serves Rex with the app's built-in Tailscale, as the node <name>-rex, on port 443
# (modules/darwin/rex.nix). `icon` in mac.json names its SF Symbol.
++ lib.mapAttrsToList
  (dir: _:
    let
      mac = lib.importJSON ../hosts/${dir}/mac.json;
      name = mac.name or dir;
    in
    server name "https://${name}-rex.${vars.tailnet}" (mac.icon or "laptopcomputer"))
  macs
