# ═══════════════════════════════════════════════════════════════════════════
# azure-mcp: Microsoft's Azure MCP Server (`azmcp`), which is what lets Claude Code TOUCH
# portal.azure.com by command (resource group, storage, keyvault, monitor, RBAC and so on)
# instead of us clicking through the interface.
#
# It is NOT in nixpkgs (checked on 14/08/2026, stable and unstable). And the recipe Microsoft
# publishes is `npx -y @azure/mcp@latest server start`, which rule 13 forbids: an implicit
# "latest" plus a fetch with no hash ON EVERY START of the MCP, which means the server could
# change version in the middle of a session. Here the binary is FIXED.
#
# WHY VENDOR A BINARY and not build from source: npm's `@azure/mcp` is only a JS shim that picks,
# in the postinstall, one of the six `@azure/mcp-<os>-<arch>` packages. What has the real server
# is the platform package, and inside it comes ONE self-contained 150 MB .NET binary (AOT,
# `dist/azmcp`), with no JS to run and no C# source in the tarball. So we fetch the platform
# tarball directly and skip node entirely: no `nodejs` in the closure, and `npx` drops out of the
# picture.
#
# WHY LD_LIBRARY_PATH AND NOT RPATH, which would be the right thing in Nix: the app is
# single-file and it UNPACKS the .NET native libs into `~/.net/azmcp/<hash>/` on the first start
# (`libpal_azure_c_shared_openssl3.so` is there, you can check). It is that extracted .so, outside
# the store and with no RUNPATH of ours, that dlopens libssl, so `runtimeDependencies` (which only
# touches the RPATH of the store binary) does NOT reach it. TRIED AND REJECTED in this order, with
# each one's error: with nothing, `Couldn't find a valid ICU package`; with icu plus openssl in
# `runtimeDependencies`, ICU passes but `No usable version of libssl was found` shows up, plus a
# core dump. The wrapper's LD_LIBRARY_PATH is inherited by the extracted libs and solves both.
#
# THE DEPENDENCIES, all MEASURED against the binary (not copied from a tutorial):
#   • icu plus openssl plus libstdc++: the .NET runtime. Without them the binary does not even
#     start.
#   • libsecret plus dbus: this is the pair that is NOT obvious and the one that decides whether
#     you can log in at all. `azmcp` tries the whole DefaultAzureCredential chain and the last
#     link, DeviceCodeCredential (the "open login.microsoft.com/device and type ABC123" one),
#     does a "persistence check" on the MSAL token cache BEFORE issuing the code. That check is
#     libsecret talking to the Secret Service over D-Bus, this machine's gnome-keyring. Without
#     them the error is `Persistence check failed`, with no hint at all that the problem is a
#     missing library, and the ONLY way out left in the chain would be installing azure-cli:
#     1.19 GiB of closure to do the same login. With them, the cost is ~0 (both are already on
#     the system through Plasma/keyring).
#     The `msalruntime`/libX11 that show up in the error log do NOT matter: that is the WAM
#     broker, which only exists on Windows, and the chain steps right over it.
#
# BUMPING THE VERSION: change `version` and the hashes of BOTH architectures. The hashes come
# ready from the registry, in the SRI format fetchurl accepts:
#   curl -sL https://registry.npmjs.org/@azure/mcp-linux-x64/latest \
#     | jq -r '.version, .dist.integrity'
# (same thing swapping -x64 for -arm64). npm's `latest` today is a BETA, which is the channel
# Microsoft publishes, not a choice of ours.
# ═══════════════════════════════════════════════════════════════════════════
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

  # The libs .NET opens by dlopen, which is why they do NOT fit in the RPATH (see the header):
  # they go in as LD_LIBRARY_PATH in the wrapper.
  runtimeLibs = [
    icu
    openssl
    libsecret
    dbus.lib
    stdenv.cc.cc.lib
  ];

  # One entry per supported platform: the tarball is PRE-COMPILED, so moving to another machine
  # (rule 3) requires the new architecture's hash, not a rebuild.
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

  # The binary is single-file .NET: stripping would scramble the bundle it unpacks at runtime. It
  # comes stripped from the factory anyway.
  dontStrip = true;

  # The whole `dist/`, and not just the binary: next to it comes
  # `Instrumentation/Resources/` (the .md files the `azmcp_bestpractices` tool serves). .NET finds
  # that path through /proc/self/exe, which is resolved AFTER the wrapper's execv, hence
  # `makeBinaryWrapper` (execv in C) and not a shell wrapper, which besides not solving that
  # would leave one extra process hanging on the MCP's stdio.
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
