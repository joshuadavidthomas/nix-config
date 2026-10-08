{
  lib,
  callPackage,
  python3,
  runCommand,
  inputs,
}:
let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  pythonSet =
    (callPackage inputs.pyproject-nix.build.packages { python = python3; }).overrideScope
      (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          (workspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
        ]
      );

  venv = pythonSet.mkVirtualEnv "llm-env" workspace.deps.default;
in
# the venv's bin/ also carries every dependency's entry points; expose only llm
runCommand "llm-0.36" { meta.mainProgram = "llm"; } ''
  mkdir -p $out/bin
  ln -s ${venv}/bin/llm $out/bin/llm
''
