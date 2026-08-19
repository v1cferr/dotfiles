# CODEX (OpenAI's CLI): the OFFICIAL release binary, because nixpkgs is always a release behind.
# Why the `-package-` artifact and what is dropped from it: docs/notes/apps/codex.md
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

  # The `-package-` asset and NOT the bare `codex-` one: that ships the entrypoint ALONE, and
  # `codex-code-mode-host` next to it is what runs commands. See the note.
  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-jHkFAK8rpudM5JSP4mxlGsH3f227AFtHyNJv9xEUYmI=";
  };

  # Several entries at the root (bin/, codex-path/, codex-resources/), so unpackPhase has no
  # single directory to chdir into and refuses with "unpacker produced multiple directories".
  sourceRoot = ".";

  nativeBuildInputs = [ makeBinaryWrapper ];

  # A released artifact: stripping it makes the binary stop matching what upstream published,
  # and the 251 MiB is Rust debug info that `codex doctor` reports on.
  dontStrip = true;

  # `bin/` only. The bundled `codex-path/rg` and `codex-resources/{bwrap,zsh}` stay behind, and
  # the zsh could not run here anyway: it is the one dynamically linked file in the tarball.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/codex bin/codex-code-mode-host -t $out/bin
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
