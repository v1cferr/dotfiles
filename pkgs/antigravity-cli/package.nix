# ANTIGRAVITY CLI (`agy`): Google's OFFICIAL release binary, the agent that replaced Gemini CLI.
# Why not gemini-cli, why not nixpkgs, and what the login writes: docs/notes/apps/antigravity-cli.md
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
  callPackage,
}:

let
  # version, url and hash: the ONLY file the bump writes. sha512 is what the manifest PUBLISHES.
  source = lib.importJSON ./source.json;
in
stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (source) version;

  src = fetchurl { inherit (source) url hash; };

  # The tarball is ONE file at the root (`antigravity`), so there is no directory to chdir into.
  sourceRoot = ".";

  # A Go binary, but linked against glibc: without the patch its interpreter does not exist here.
  nativeBuildInputs = [ autoPatchelfHook ];

  dontConfigure = true;
  dontBuild = true;

  # The tool answers to `agy` everywhere (its docs, its own messages), so the rename is the API.
  installPhase = ''
    runHook preInstall
    install -Dm755 antigravity $out/bin/agy
    runHook postInstall
  '';

  # It runs `agy --version` against the store path, which is what proves the patch took.
  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  # What vendored-bump runs on `update`.
  passthru.updateScript = callPackage ./bump.nix { };

  meta = {
    description = "Google's agent CLI, the successor to Gemini CLI (official release binary)";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
}
