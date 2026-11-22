{ lib, ... }:
let
  # The menu bar icon: a dot, filled while the hidden section shows.
  icon = builtins.toJSON {
    name = "Dot";
    visible.catalog._0 = "DotStroke";
    hidden.catalog._0 = "DotFill";
  };
in
{
  # Thaw, the menu bar manager, a fork of Ice that keeps Ice's setting names. These are the
  # settings that Ice had on the Mac mini. targets.darwin.defaults writes only these keys
  # (defaults import merges), so the app's own state stays.
  targets.darwin.defaults."com.stonerl.Thaw" = {
    AutoRehide = true;
    RehideStrategy = 0; # after an interval
    RehideInterval = 15.0;
    TempShowInterval = 15.0;
    EnableAlwaysHiddenSection = false;
    EnableSecondaryContextMenu = true;
    HideApplicationMenus = true;
    ShowAllSectionsOnUserDrag = true;
    ShowIceIcon = true;
    ShowOnClick = true;
    ShowOnHover = false;
    ShowOnHoverDelay = 0.2;
    ShowOnScroll = true;
    SectionDividerStyle = 0;
    UseIceBar = true; # show the hidden items in a bar below the menu bar
    IceBarLocation = 0;
  };

  # Thaw keeps the icon as data, which targets.darwin.defaults cannot write.
  home.activation.thawIcon = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write com.stonerl.Thaw IceIcon -data \
      "$(printf '%s' ${lib.escapeShellArg icon} | /usr/bin/xxd -p | tr -d '\n')"
  '';
}
