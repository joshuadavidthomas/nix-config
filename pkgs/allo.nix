# Allo, the font by Josh Puckett (allo.joshpuckett.me), from its release zip. nixpkgs does not
# have it. Allo is the static family, nine weights with an oblique of each; Allo Variable has
# the weight, optical size and roundness axes, but no obliques. Both are installed.
{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "allo";
  version = "1.0.3";

  src = fetchzip {
    url = "https://github.com/joshpuckett/allo/releases/download/v${finalAttrs.version}/Allo-${finalAttrs.version}.zip";
    hash = "sha256-wKyKi7vS95W32sUq7ws0bZa0MwJIPUdo0dAykMGdL/g=";
  };

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/opentype fonts/otf/*.otf
    install -Dm644 -t $out/share/fonts/truetype fonts/variable/*.ttf
    runHook postInstall
  '';

  meta = {
    homepage = "https://allo.joshpuckett.me";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
})
