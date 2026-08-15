# CurseForge — o app OFICIAL (Electron, da Overwolf) de modpacks do Minecraft.
# Substituiu o prismlauncher em 14/08/2026: o Prism instala modpack do CurseForge por
# import de .zip, sem a biblioteca/atualização de pack que é o motivo de existir do app.
#
# NÃO está no nixpkgs (é unfree e binário-only), então o repo reempacota o AppImage
# oficial — mesmo padrão de vendor binário do claude-desktop.
#
# ⚠️ NÃO ADICIONE JAVA AQUI — já foi tentado, e é CONFIG MORTA (medido em 15/08/2026).
# O app BAIXA e gerencia a própria JRE em `~/Documents/curseforge/minecraft/Install/java/`,
# e é a única que ele consulta: com `java` no PATH do FHS e três JRE em /usr/lib/jvm, o log
# do agent seguiu citando 18× o java DELE e ZERO vez o nosso. Os três saíram no mesmo
# commit em que entraram. O erro "Java Runtime Environment is missing" NÃO se conserta por
# aqui — a causa é PERMISSÃO, ver `curseforge-fix-java` (pkgs/curseforge-fix-java.nix).
#
# POR QUE AppImage e NÃO o .deb (as duas fontes existem e são a MESMA release): tudo que
# importa aqui é binário que o app BAIXA em runtime — a JRE, o instalador do Forge, o
# próprio Minecraft — e nada disso passa por `autoPatchelfHook`, que só alcança o que está
# na store. O `programs.nix-ld` deste sistema até cobre o loader (o /lib64/ld-linux daqui
# aponta pra ele), mas não as bibliotecas de cada um; o `buildFHSEnv` do appimageTools
# resolve os dois de uma vez e ainda põe /run/opengl-driver/lib no ld.so.conf (via
# `container-init.cc`), então o Minecraft herda o FHS **e** o driver da Arc B580. É o FHS
# que sustenta o pacote, não o patchelf.
#
# ⚠️ URL-PONTEIRO: a Overwolf só publica `curseforge-latest-linux.AppImage`; não existe
# URL versionada (testados os padrões `-1.316.0-`, `~37372`, `latest.yml` → 404). O
# `hash` abaixo TRAVA o conteúdo, então o build é reprodutível — mas quando a Overwolf
# publicar a próxima versão o fetch passa a falhar por hash mismatch em store fria (foi
# exatamente o que o `/latest/` do VS Code causou no CI). Quem paga esse preço é o
# `curseforge-bump` (pkgs/curseforge-bump.nix), que roda no alias `update` e reescreve
# version+hash daqui. NÃO trocar por `lib.fakeHash` nem por fetch sem hash (regra 13).
#
# ⚠️ O auto-updater interno do app (`resources/app-update.yml`, provider gitlab) NÃO
# funciona — a store é read-only. Atualizar é `update`/`upgrade`, como todo o resto.
{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "curseforge";
  # Do `X-AppImage-Version` do .desktop de dentro do AppImage (o control do .deb da mesma
  # release diz `1.316.0~37372-37372`). O `.37372` repetido é ruído do electron-builder.
  version = "1.316.0-37372";

  src = fetchurl {
    url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
    hash = "sha256-ZH4ZkFSoT8bQgcQPkszcux4gds4DHwrD7Vyub+13mgQ=";
  };

  # extract + wrapAppImage em vez do wrapType2 (que faz os dois de uma vez): o
  # extraInstallCommands precisa LER a árvore extraída pra pegar o .desktop e os ícones,
  # e o wrapType2 não a expõe.
  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  # O `.desktop` do upstream traz `Exec=AppRun --no-sandbox %U`; aqui só o AppRun vira o
  # nome do wrapper do FHS — o resto fica como o upstream escreveu.
  # Sobre o `--no-sandbox`: NÃO é necessário aqui. Medido em 14/08/2026 rodando
  # `bin/curseforge` (que não passa flag nenhuma): o app abre e carrega a biblioteca
  # normalmente, sem o "SUID sandbox helper" que esta flag costuma contornar — o bwrap do
  # buildFHSEnv já dá o namespace que o Chromium quer. Fica porque veio do upstream e não
  # custa nada; divergir do `.desktop` deles exigiria um motivo, e não há.
  # `%U` + os MimeType `x-scheme-handler/curseforge…` são o que faz o botão "Install" do
  # site abrir o app (deep link). Declarar o scheme aqui não basta: quem diz que ESTE
  # .desktop é o default é o home/apps/curseforge.nix — e sem isso o LOGIN não volta
  # (a pegadinha inteira, medida, está documentada lá).
  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/curseforge.desktop \
      -t $out/share/applications
    substituteInPlace $out/share/applications/curseforge.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    # O AppImage já traz a árvore hicolor completa (16 → 1024) — copiar é melhor que
    # eleger um tamanho: o ícone sai nítido na barra e no menu.
    cp -r ${appimageContents}/usr/share/icons $out/share/
  '';

  meta = {
    description = "App oficial do CurseForge — biblioteca e atualização de modpacks (Minecraft/WoW)";
    homepage = "https://www.curseforge.com/download/app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
