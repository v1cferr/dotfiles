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
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

{
  home.activation.dolphinDetailsView = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    kw="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"
    run "$kw" --file "$HOME/.config/dolphinrc" --group General --key GlobalViewProps true
    dir="$HOME/.local/share/dolphin/view_properties/global"
    run mkdir -p "$dir"
    run "$kw" --file "$dir/.directory" --group Dolphin --key ViewMode 2
    run "$kw" --file "$dir/.directory" --group Dolphin --key Version 4
  '';
}
