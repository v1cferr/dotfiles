# ANTIGRAVITY CLI (`agy`): Google's OFFICIAL release binary, the agent that replaced Gemini CLI.
# Why not gemini-cli, why not nixpkgs, and what the login writes: docs/notes/apps/antigravity-cli.md
{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  versionCheckHook,
}:

let
  # An opaque BUILD ID sits next to the version in the URL, and only the manifest knows it.
  # antigravity-bump rewrites it together with the version and the hash.
  buildId = "6563996145418240";
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "antigravity-cli";
  # From the publisher's `latest` endpoint, which is what the bump asks.
  version = "1.1.20";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${finalAttrs.version}-${buildId}/linux-x64/cli_linux_x64.tar.gz";
    # sha512 because that is what the manifest PUBLISHES: the bump converts it and downloads nothing.
    hash = "sha512-3XFolnxWc6WOi6jzDU354Uz9a+gWQ81lPtR4XXT792Clgm/E2W97S4iwLb3sHkVTZiA6w4qT6iJquMhjRl4LMA==";
  };

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

  meta = {
    description = "Google's agent CLI, the successor to Gemini CLI (official release binary)";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "agy";
  };
})
