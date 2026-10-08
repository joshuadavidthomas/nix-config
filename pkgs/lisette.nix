# nixpkgs `lisette` trails upstream; use the release binaries.
{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "0.12.3";
  platforms = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-pX/ac7Woj16yh+ju2Hbe+ovGvVy7qnOCY1pLyMfFTzY=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-z3UlB0hZft0TImBuARNZ3qYgle0/SR8f5QAEDDWL0gg=";
    };
  };
  platform = platforms.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "lisette";
  inherit version;

  src = fetchurl {
    url = "https://github.com/ivov/lisette/releases/download/lisette-v${version}/lisette-${platform.target}.tar.xz";
    inherit (platform) hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 lis $out/bin/lis
    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/ivov/lisette";
    mainProgram = "lis";
    platforms = lib.attrNames platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
