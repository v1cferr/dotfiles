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
{ pkgs, lib, ... }:

let
  # Bloco XBEL do bookmark "FAI Workstation" (a pasta do rclone SFTP, ~/FAI-workstation).
  faiPlace = pkgs.writeText "fai-place.xbel" ''
     <bookmark href="file:///home/v1cferr/FAI-workstation">
      <title>FAI Workstation</title>
      <info>
       <metadata owner="http://freedesktop.org">
        <bookmark:icon name="folder-remote"/>
       </metadata>
       <metadata owner="http://www.kde.org">
        <ID>1784500000/0</ID>
        <isSystemItem>false</isSystemItem>
       </metadata>
      </info>
     </bookmark>
  '';
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

  # Bookmark "FAI Workstation" no painel Places (declarativo, idempotente). MESMO motivo
  # do details-view: o Dolphin reescreve o user-places.xbel em runtime (monta disco/adiciona
  # lugar) → symlink imutável brigaria + travaria os teus lugares. Então insere o bookmark
  # SÓ se ainda não estiver lá, deixando o resto mutável. Reproduzível em qualquer máquina
  # (não hardcoda as entradas de disco, que são específicas do hardware).
  home.activation.faiWorkstationPlace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    xbel="$HOME/.local/share/user-places.xbel"
    if [ -f "$xbel" ] && ! grep -q FAI-workstation "$xbel"; then
      tmp="$(mktemp)"
      grep -v '</xbel>' "$xbel" > "$tmp"
      cat ${faiPlace} >> "$tmp"
      printf '</xbel>\n' >> "$tmp"
      run mv "$tmp" "$xbel"
    fi
  '';
}
