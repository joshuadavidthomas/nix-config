{ lib, pkgs, ... }:
let
  # Helium is a cask (modules/darwin/default.nix). These go into its Default profile.
  extensions = {
    "1password" = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";
    chatgpt = "hehggadaopoacecdllhhajmbjkdcmajg";
    raindrop = "ldgfbffkinooeloadekpmfoklnobpien";
    enhancer-for-youtube = "ponfpcnoihfmfllpaingbgckeeldkhle";
  };
in
{
  # Helium has no sync, so the switch installs the extensions and sets the settings that
  # differ from Helium's defaults on the Mac mini. Helium adds the extensions disabled, as it
  # does with each extension that it did not install itself; it asks once to enable each. See
  # helium-profile.py.
  home.activation.heliumProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d /Applications/Helium.app ]; then
      run ${lib.getExe pkgs.python3} ${./helium-profile.py} ${pkgs.writeText "helium-profile.json" (builtins.toJSON {
        extensions = lib.attrValues extensions;
        preferences = {
          helium.browser = {
            layout = 2;
            centered_location_bar = true;
            minimal_location_bar = true;
          };
          browser.theme.is_grayscale2 = true;
          extensions.pinned_extensions = [ extensions."1password" extensions.raindrop ];
        };
      })} \
        || warnEcho "helium: could not set up its profile; run 'rebuild' again"
    fi
  '';

  # Helium is the default web browser. macOS asks you to confirm the change, so the step runs
  # only when Helium is not the default yet. defaultbrowser lists the browsers that macOS
  # knows, and marks the default with *.
  home.activation.heliumDefaultBrowser = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d /Applications/Helium.app ] \
      && ! ${lib.getExe pkgs.defaultbrowser} | grep -qx '\* helium'; then
      run ${lib.getExe pkgs.defaultbrowser} helium \
        || warnEcho "helium: could not make it the default browser; run 'rebuild' again"
    fi
  '';
}
