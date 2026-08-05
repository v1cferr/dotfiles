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
#   view_properties/global/.directory [Dolphin] ViewMode=2  → 2 = Detalhes
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
      path = config.my.drive.local; # SSOT: home/services/drive-sync.nix (regra 11)
      icon = "folder-gdrive";
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
    dir="$HOME/.local/share/dolphin/view_properties/global"
    run mkdir -p "$dir"
    run "$kw" --file "$dir/.directory" --group Dolphin --key Version 4
    # kwriteconfig6 não sabe escrever o marcador [$i] → grava a chave normal (ele
    # cria/posiciona o grupo certo) e o sed a promove p/ imutável. O guard é
    # obrigatório: sobre uma chave já imutável o kwriteconfig6 sai 2, e a activation
    # roda com `set -e` → abortaria o resto do home-manager.
    if ! grep -qF 'ViewMode[$i]=2' "$dir/.directory" 2>/dev/null; then
      run "$kw" --file "$dir/.directory" --group Dolphin --key ViewMode 2
      run ${pkgs.gnused}/bin/sed -i 's/^ViewMode=2$/ViewMode[$i]=2/' "$dir/.directory"
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
