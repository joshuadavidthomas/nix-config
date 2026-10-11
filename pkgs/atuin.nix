# nixpkgs `atuin` trails upstream (it has 18.21.0), and the history db is already migrated to
# 18.23.0's schema, so an older atuin can't open it. Use the release binaries; building from
# source takes 6 to 20+ minutes. Drop once nixpkgs reaches 18.23.0.
{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
}:
let
  version = "18.23.0";
  platforms = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-yYi+HN4ZzXKVzmS8i5VdQvsYVeUifLZAyH/AnIQIw/w=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl"; # static, so NixOS needs no patching
      hash = "sha256-0bQN1ufNPYI4Z//iKzmgJbxCD3h1kmrpypdBVTeNoU0=";
    };
  };
  platform = platforms.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "atuin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/atuinsh/atuin/releases/download/v${version}/atuin-${platform.target}.tar.gz";
    inherit (platform) hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 atuin $out/bin/atuin
    runHook postInstall
  '';

  # as nixpkgs' recipe does
  postInstall = ''
    installShellCompletion --cmd atuin \
      --bash <($out/bin/atuin gen-completions -s bash) \
      --fish <($out/bin/atuin gen-completions -s fish) \
      --zsh <($out/bin/atuin gen-completions -s zsh)
  '';

  meta = {
    homepage = "https://github.com/atuinsh/atuin";
    license = lib.licenses.mit;
    mainProgram = "atuin";
    platforms = lib.attrNames platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
