# CODEX (OpenAI's CLI): the OFFICIAL release binary, because nixpkgs is always a release behind.
# Why the prebuilt musl artifact and not a source build: docs/notes/apps/codex.md
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeBinaryWrapper,
  ripgrep,
  bubblewrap,
}:

let
  # Hoisted out of the antiquotation: inline, nixfmt explodes the list across the shell snippet.
  runtimeDeps = lib.makeBinPath [
    ripgrep
    bubblewrap
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  # From the release tag (`rust-v<version>`); codex-bump rewrites it along with the hash.
  version = "0.148.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-Gjb3YvazvvUzu4Y0WtlRdmHC2E1TmWolDPLKidLP7lo=";
  };

  # The tarball is ONE file at the root, and stdenv's unpackPhase has no directory to chdir into.
  sourceRoot = ".";

  nativeBuildInputs = [ makeBinaryWrapper ];

  # A released artifact: stripping it makes the binary stop matching what upstream published,
  # and the 251 MiB is Rust debug info that `codex doctor` reports on.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 codex-x86_64-unknown-linux-musl $out/bin/codex
    runHook postInstall
  '';

  # The same two nixpkgs puts on the PATH: without `rg` the search dies, without `bwrap` the
  # sandbox does. `--inherit-argv0` because Codex re-executes itself as its sandbox helper.
  postFixup = ''
    wrapProgram $out/bin/codex --inherit-argv0 --prefix PATH : ${runtimeDeps}
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal (official release binary)";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "codex";
  };
})
