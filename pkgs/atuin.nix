# nixpkgs' recipe at the version that already migrated the history db (nixpkgs has 18.21.0).
# Drop once nixpkgs reaches 18.23.0.
{ atuin, fetchFromGitHub, rustPlatform }:
atuin.overrideAttrs (finalAttrs: old: {
  version = "18.23.0";
  src = fetchFromGitHub {
    owner = "atuinsh";
    repo = "atuin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NBn7C9ssLSXYrHWv5qWM5dZ2E8URbRJZOOCvHaNgxW4=";
  };
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-rkDDs8gviBpoLR4mrrKRu2eTlmlpvjICVRFu22AeOaU=";
  };
  # 18.23.0 adds end-to-end tests that drive real shells in a pty. These two can't get a
  # shell running inside the build sandbox and time out; the other pty tests pass.
  checkFlags = old.checkFlags ++ [
    "--skip=filtered_commands_leave_no_captured_output"
    "--skip=setup_2_tests_shells_bash_preexec_toml" # every case using the bash-preexec fixture
  ];
})
