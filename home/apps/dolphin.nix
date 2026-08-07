# ═══════════════════════════════════════════════════════════════════════════
# DOLPHIN (KDE) — view mode sempre "Detalhes", declarado.
#
# O Dolphin REESCREVE seus KConfig em runtime → um symlink imutável do
# home-manager quebraria as outras prefs (tamanho de janela, etc.). Então em vez
# de gerenciar o arquivo, um activation script força SÓ as chaves que queremos
# (idempotente), deixando o resto mutável pro Dolphin.
#
# "Sempre Detalhes" = duas chaves:
#   dolphinrc [General] GlobalViewProps=true  → mesmo modo em TODA pasta
#   view_properties/global/.directory [Dolphin] ViewMode=1  → 1 = Detalhes
#
# ⚠️ O VALOR NÃO SEGUE A ORDEM DO MENU. Ficou 2 aqui de 18/07 a 07/08/2026 e o efeito era
# Compact — o pin funcionava, só apontava pro modo errado, e por ser imutável trocar pra
# Detalhes na sessão nunca colava. O enum é `DolphinView::Mode` (src/views/dolphinview.h):
# 0 = Icons, 1 = Details, 2 = Compact. O menu lista Icons/Compact/Details (Ctrl+1/2/3), que
# é outra ordem, e o `whatsthis` do kcfg piora chamando o 2 de "column" (nome antigo do
# Compact). Conferir no header do fonte, nunca no menu nem no kcfg.
#
# E o ViewMode vai IMUTÁVEL — `ViewMode[$i]=2`, o marcador de kiosk do KConfig.
# Não é preciosismo: desde o 26.04 o Dolphin guarda as view properties num xattr
# do diretório (user.kde.fm.viewproperties#1) e trata o .directory como legado —
# o save() chama cleanDotDirectoryFile(), que faz deleteGroup("Dolphin") e APAGA
# o arquivo (viewproperties.cpp). Só o marcador sobrevive a isso: o KConfig recusa
# a remoção, o grupo não fica vazio, o arquivo fica. E como o .directory tem
# precedência sobre o xattr na leitura, ele é a âncora declarativa — o Dolphin
# inclusive copia o `[$i]` p/ dentro do xattr no primeiro save.
#
# As outras props (ordenação, colunas, miniaturas) seguem mutáveis. Trocar de modo
# na sessão funciona — só não persiste; p/ mudar de vez, editar aqui.
# ═══════════════════════════════════════════════════════════════════════════
{
  pkgs,
  lib,
  config,
  ...
}:

let
  # `DolphinView::Mode` (src/views/dolphinview.h): 0 = Icons, 1 = Details, 2 = Compact.
  # Nomeado porque o número cru é ARMADILHA — ver o ⚠️ do cabeçalho.
  viewModeDetails = 1;

  # LUGARES FIXOS no painel Places do Dolphin. Adicionar um = 1 linha nesta lista.
  # Os nomes de ícone foram conferidos no breeze-icons 6.26.0 (places/22): nome que não
  # existe não quebra nada, só cai num ícone genérico de pasta.
  places = [
    {
      title = "FAI Workstation";
      path = "/home/v1cferr/FAI-workstation"; # rclone SFTP; sobe com a VPN da FAI
      icon = "folder-remote";
    }
    {
      title = "Obsidian";
      path = "/home/v1cferr/Dropbox/Obsidian"; # cofre de notas (sincronizado pelo Dropbox)
      icon = "folder-notes";
    }
    {
      title = "Drive";
      path = config.my.drive.local; # SSOT: home/services/drive-mount.nix (regra 11)
      icon = "folder-gdrive";
    }
    # Os dois abaixo só têm conteúdo COM O MOUNT DE PÉ (`backup-browse`/`arch-browse`).
    # Vazio = não montado, e isso é informação, não bug: são consultas raras e um mount
    # permanente de repo cifrado remoto seria conexão aberta e lock no repo por nada.
    {
      title = "Backup (snapshots)";
      path = "/mnt/backup"; # repo do home no Drive; read-only, um dir por snapshot
      icon = "folder-tar";
    }
    {
      title = "Arch antigo";
      path = "/mnt/arch-antigo"; # acervo de quando o Kingston era Arch Linux
      icon = "folder-locked";
    }
  ];

  # Um arquivo XBEL por lugar. O `<ID>` do KDE tem que ser ÚNICO por bookmark — vem do
  # índice, pra não haver colisão nem número mágico repetido na mão.
  placeFiles = lib.imap0 (
    i: p:
    p
    // {
      file = pkgs.writeText "dolphin-place-${toString i}.xbel" ''
        <bookmark href="file://${p.path}">
         <title>${p.title}</title>
         <info>
          <metadata owner="http://freedesktop.org">
           <bookmark:icon name="${p.icon}"/>
          </metadata>
          <metadata owner="http://www.kde.org">
           <ID>1784500000/${toString i}</ID>
           <isSystemItem>false</isSystemItem>
          </metadata>
         </info>
        </bookmark>
      '';
    }
  ) places;
in
{
  # Dolphin (KDE) + extras que ligam recursos: kio-extras = SFTP/SMB/MTP (celular
  # via USB); thumbnailers = miniaturas de imagem/pdf/vídeo. Lixeira (trash:/) nativa.
  home.packages = with pkgs.kdePackages; [
    dolphin
    kio-extras
    kdegraphics-thumbnailers
    ffmpegthumbs
    ark # gerenciador de arquivos compactados + servicemenus "Comprimir/Extrair" no botão-direito
  ];

  home.activation.dolphinDetailsView = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key GlobalViewProps true

    # TAMANHO do ícone na visão Detalhes. Sem isto as pastas saem em LINE ART
    # monocromática, e não nas amarelas do Windows 11: o tema Win11 só tem arte colorida
    # em `places/16` e `places/scalable` — o `places/22` é `fill="currentColor"`, e 22 é
    # justamente o default. (O Fluent tinha o mesmo 22 monocromático; só não aparecia
    # porque a visão era Compact, que pede ícone grande e caía no scalable.)
    #
    # A CHAVE É `PreviewSize`, NÃO `IconSize` — custou duas tentativas erradas. Com
    # preview LIGADO (nosso caso, decidido em 07/08) o Dolphin ignora `IconSize`:
    #   dolphinitemlistview.cpp:172
    #   const int iconSize = previewsShown() ? settings.previewSize() : settings.iconSize();
    # Os dois vão pra 32 de propósito, pra o tamanho não pular quando você desliga o
    # preview pra garimpar o /mnt/arch-antigo. 32 é degrau válido do ZoomLevelInfo
    # (16/22/32/48/…) e o 1º que entra na faixa do `places/scalable` (MinSize=32).
    # NÃO vai imutável: assim o Ctrl+scroll continua funcionando na sessão. Zoom que
    # pare em 22 traz o line art de volta — é o preço de deixar o zoom livre.
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key PreviewSize 32
    run "$kw" --file "$HOME/.config/dolphinrc" --group DetailsMode --key IconSize 32

    dir="$HOME/.local/share/dolphin/view_properties/global"
    run mkdir -p "$dir"
    run "$kw" --file "$dir/.directory" --group Dolphin --key Version 4
    # kwriteconfig6 não sabe escrever o marcador [$i] → grava a chave normal (ele
    # cria/posiciona o grupo certo) e o sed a promove p/ imutável. O guard é
    # obrigatório: sobre uma chave já imutável o kwriteconfig6 sai 2, e a activation
    # roda com `set -e` → abortaria o resto do home-manager.
    if grep -qF 'ViewMode[$i]=${toString viewModeDetails}' "$dir/.directory" 2>/dev/null; then
      : # já no valor certo e imutável
    elif grep -qF 'ViewMode[$i]=' "$dir/.directory" 2>/dev/null; then
      # Já imutável, mas com OUTRO valor — o caso do 2→1. Aqui o kwriteconfig6 sairia 2 e
      # derrubaria a activation, então a linha é reescrita direto.
      run ${pkgs.gnused}/bin/sed -i \
        's/^ViewMode\[\$i\]=.*$/ViewMode[$i]=${toString viewModeDetails}/' "$dir/.directory"
    else
      run "$kw" --file "$dir/.directory" --group Dolphin --key ViewMode ${toString viewModeDetails}
      run ${pkgs.gnused}/bin/sed -i \
        's/^ViewMode=${toString viewModeDetails}$/ViewMode[$i]=${toString viewModeDetails}/' "$dir/.directory"
    fi
  '';

  # Bookmarks no painel Places (declarativo, idempotente). MESMO motivo do details-view:
  # o Dolphin reescreve o user-places.xbel em runtime (monta disco/adiciona lugar) →
  # symlink imutável brigaria + travaria os teus lugares. Então insere cada bookmark SÓ
  # se ainda não estiver lá, deixando o resto mutável. Reproduzível em qualquer máquina
  # (não hardcoda as entradas de disco, que são específicas do hardware).
  #
  # O teste é POR LUGAR e casa pelo CAMINHO, não pela lista inteira: com um guard só, um
  # lugar novo nunca entraria (o arquivo já teria o antigo) ou os antigos duplicariam.
  # Sem `exit` aqui de propósito — a activation do home-manager é um script único, e um
  # `exit` abortaria tudo o que vem depois.
  home.activation.dolphinPlaces = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    xbel="$HOME/.local/share/user-places.xbel"
    ${lib.concatMapStrings (p: ''
      if [ -f "$xbel" ] && ! grep -qF '${p.path}' "$xbel"; then
        tmp="$(mktemp)"
        grep -v '</xbel>' "$xbel" > "$tmp"
        cat ${p.file} >> "$tmp"
        printf '</xbel>\n' >> "$tmp"
        run mv "$tmp" "$xbel"
      fi
    '') placeFiles}
  '';
}
