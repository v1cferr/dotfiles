# ═══════════════════════════════════════════════════════════════════════════
# azure-mcp — o Azure MCP Server (`azmcp`) da Microsoft, que é o que deixa o
# Claude Code MEXER no portal.azure.com por comando (grupo, storage, keyvault,
# monitor, RBAC…) em vez de a gente clicar na interface.
#
# NÃO está no nixpkgs (conferido em 14/08/2026, stable e unstable). E a receita
# que a Microsoft publica é `npx -y @azure/mcp@latest server start`, que a regra
# 13 proíbe: "latest" implícito + fetch sem hash A CADA START do MCP, ou seja o
# servidor podia mudar de versão no meio de uma sessão. Aqui o binário é FIXO.
#
# POR QUE VENDOR BINÁRIO e não build do fonte: o `@azure/mcp` do npm é só um
# shim JS que escolhe, no postinstall, um dos seis pacotes `@azure/mcp-<os>-<arch>`.
# Quem tem o server de verdade é o pacote da plataforma, e dentro dele vem UM
# binário .NET self-contained de 150 MB (AOT, `dist/azmcp`) — não há JS pra
# rodar nem fonte C# no tarball. Então buscamos direto o tarball da plataforma e
# pulamos o node inteiro: nada de `nodejs` no closure, e o `npx` some da conta.
#
# ⚠️ POR QUE LD_LIBRARY_PATH E NÃO RPATH, que seria o certo em Nix: o app é
# single-file e DESEMPACOTA as libs nativas do .NET em `~/.net/azmcp/<hash>/` no
# primeiro start (o `libpal_azure_c_shared_openssl3.so` está lá, dá pra conferir).
# É esse .so extraído — fora da store, sem RUNPATH nosso — quem faz o dlopen do
# libssl, então `runtimeDependencies` (que só mexe no RPATH do binário da store)
# NÃO alcança. TENTADO E RECUSADO nesta ordem, com o erro de cada um: sem nada,
# `Couldn't find a valid ICU package`; com icu+openssl em `runtimeDependencies`,
# ICU passa mas vem `No usable version of libssl was found` + core dump. O
# LD_LIBRARY_PATH do wrapper é herdado pelas libs extraídas e resolve os dois.
#
# DEPENDÊNCIAS, todas MEDIDAS no binário (não copiadas de tutorial):
#   • icu + openssl + libstdc++ — runtime do .NET. Sem elas o binário nem sobe.
#   • libsecret + dbus — este é o par que NÃO é óbvio e
#     é o que decide se dá pra logar. O `azmcp` tenta a cadeia inteira do
#     DefaultAzureCredential e o último elo, o DeviceCodeCredential (aquele
#     "abra login.microsoft.com/device e digite ABC123"), faz um "persistence
#     check" no cache de token do MSAL ANTES de emitir o código. Esse check é
#     libsecret falando com o Secret Service por D-Bus — o gnome-keyring desta
#     máquina. Sem elas o erro é `Persistence check failed`, sem nenhuma pista de
#     que o problema é biblioteca faltando, e a ÚNICA saída que sobra na cadeia
#     seria instalar o azure-cli: 1,19 GiB de closure pra fazer o mesmo login.
#     Com elas, custo ~0 (as duas já estão no sistema pelo Plasma/keyring).
#     O `msalruntime`/libX11 que aparecem no log de erro NÃO importam: é o broker
#     WAM, que só existe no Windows — a cadeia passa por cima dele.
#
# BUMP DE VERSÃO: trocar `version` e os hashes das DUAS arquiteturas. Os hashes
# saem prontos do registry, no formato SRI que o fetchurl aceita:
#   curl -sL https://registry.npmjs.org/@azure/mcp-linux-x64/latest \
#     | jq -r '.version, .dist.integrity'
# (idem trocando -x64 por -arm64). O `latest` do npm hoje é uma BETA — é o canal
# que a Microsoft publica, não escolha nossa.
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

  # As libs que o .NET abre por dlopen, e por isso NÃO cabem no RPATH (ver o
  # cabeçalho): entram como LD_LIBRARY_PATH no wrapper.
  runtimeLibs = [
    icu
    openssl
    libsecret
    dbus.lib
    stdenv.cc.cc.lib
  ];

  # Uma entrada por plataforma suportada: o tarball é PRÉ-COMPILADO, então trocar
  # de máquina (regra 3) exige o hash da arquitetura nova, não um rebuild.
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
      or (throw "azure-mcp: sem tarball publicado para ${stdenv.hostPlatform.system}");
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

  # Só o que é NEEDED do próprio ELF — o autoPatchelf resolve isso no RPATH.
  buildInputs = [ stdenv.cc.cc.lib ];

  # O binário é single-file .NET: o strip embaralharia o bundle que ele
  # desempacota em runtime. Já vem stripped de fábrica, de todo jeito.
  dontStrip = true;

  # O `dist/` inteiro, e não só o binário: ao lado dele vem o
  # `Instrumentation/Resources/` (os .md que a tool `azmcp_bestpractices` serve).
  # O .NET acha esse caminho por /proc/self/exe, que é resolvido DEPOIS do execv
  # do wrapper — daí o `makeBinaryWrapper` (execv em C) e não um wrapper de shell,
  # que além de não resolver isso deixaria um processo a mais pendurado no stdio
  # do MCP.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/azure-mcp $out/bin
    cp -r dist/. $out/lib/azure-mcp/
    makeBinaryWrapper $out/lib/azure-mcp/azmcp $out/bin/azmcp \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs}
    runHook postInstall
  '';

  meta = {
    description = "Azure MCP Server — gerencia recursos do Azure por MCP (binário oficial da Microsoft)";
    homepage = "https://github.com/microsoft/mcp/tree/main/servers/Azure.Mcp.Server";
    license = lib.licenses.mit;
    mainProgram = "azmcp";
    platforms = lib.attrNames srcs;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
