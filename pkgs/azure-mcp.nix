# azure-mcp: Microsoft's `azmcp`, the MCP server that drives portal.azure.com by command.
# Why a vendored binary, why LD_LIBRARY_PATH, and how to bump: docs/notes/azure-mcp.md
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  icu,
  openssl,
  libsecret,
  dbus,
}:

let
  version = "3.0.0-beta.35";

  # dlopen'd by .NET, so they do NOT fit in the RPATH: they go in as LD_LIBRARY_PATH.
  runtimeLibs = [
    icu
    openssl
    libsecret
    dbus.lib
    stdenv.cc.cc.lib
  ];

  # One entry per platform: the tarball is PRE-COMPILED, so a new arch needs a hash (rule 3).
  srcs = {
    x86_64-linux = {
      arch = "linux-x64";
      hash = "sha512-bmGL7Ds28CmPavMgCQpZtndrGR5Zmh1dV4W7fYMxRCLzhWw1iiBdyRek8Tf9yX3o9Y1zdIKqi3znKaAd8yuuvw==";
    };
    aarch64-linux = {
      arch = "linux-arm64";
      hash = "sha512-YU8IZat9q1GpN8ozTOBN723iLQog0IdON6EyuGk0Pj3kV/ARtgR2KN0rYTHQ4+ceBELaak2ChgJCNmtPTJqXOw==";
    };
  };

  src =
    srcs.${stdenv.hostPlatform.system}
      or (throw "azure-mcp: no tarball published for ${stdenv.hostPlatform.system}");
in

stdenvNoCC.mkDerivation {
  pname = "azure-mcp";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@azure/mcp-${src.arch}/-/mcp-${src.arch}-${version}.tgz";
    inherit (src) hash;
  };

  sourceRoot = "package";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  # Only what is NEEDED by the ELF itself; autoPatchelf resolves that into the RPATH.
  buildInputs = [ stdenv.cc.cc.lib ];

  # Single-file .NET: stripping would scramble the bundle it unpacks at runtime.
  dontStrip = true;

  # The whole `dist/` (Instrumentation/Resources/ sits next to the binary), and makeBinaryWrapper
  # because .NET resolves that path through /proc/self/exe, AFTER the wrapper's execv.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/azure-mcp $out/bin
    cp -r dist/. $out/lib/azure-mcp/
    makeBinaryWrapper $out/lib/azure-mcp/azmcp $out/bin/azmcp \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    runHook postInstall
  '';

  meta = {
    description = "Azure MCP Server: manages Azure resources through MCP (Microsoft's official binary)";
    homepage = "https://github.com/microsoft/mcp/tree/main/servers/Azure.Mcp.Server";
    license = lib.licenses.mit;
    mainProgram = "azmcp";
    platforms = lib.attrNames srcs;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
