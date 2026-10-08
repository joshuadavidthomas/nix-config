# Cloudflare's `cf` CLI from npm. Not in nixpkgs; upstream is a pnpm monorepo, so this
# installs the published package from a pinned lockfile instead of building from source.
# To update: bump the version in package.json, regenerate the lock with
# `npm install --package-lock-only --ignore-scripts`, and refresh npmDepsHash.
{
  lib,
  buildNpmPackage,
  nodejs_24,
}:
buildNpmPackage {
  pname = "cf";
  version = "0.15.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  nodejs = nodejs_24;
  npmDepsHash = "sha256-QYedh1hEeEMZotu/X4RdB1+5d4UXdqr7aLuXCQ666q4=";
  npmFlags = [ "--ignore-scripts" ]; # workerd's script only re-fetches its optional binary dep
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib $out/bin
    cp -r node_modules $out/lib/
    ln -s $out/lib/node_modules/cf/bin/cf $out/bin/cf
    ln -s $out/lib/node_modules/cf/bin/cf $out/bin/cloudflare
    runHook postInstall
  '';

  meta = {
    description = "The Cloudflare CLI";
    homepage = "https://github.com/cloudflare/cf";
    mainProgram = "cf";
  };
}
