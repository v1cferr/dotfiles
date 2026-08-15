# ═══════════════════════════════════════════════════════════════════════════
# CurseForge — app oficial de modpacks do Minecraft. O PACOTE (AppImage oficial
# reempacotado) mora em pkgs/curseforge.nix; aqui é o lado do usuário.
#
# SUBSTITUIU o prismlauncher em 14/08/2026: o Prism importa um .zip de modpack, mas quem
# mantém a biblioteca e ATUALIZA o pack é o app do CurseForge — que é o uso real aqui.
#
# E a troca ENCOLHEU o sistema em 1,5 GiB, o contrário do que "nativo → Electron" sugere:
# 27,2 → 25,7 GiB, medido com `nix store diff-closures`. curseforge +340,2 MiB contra
# prismlauncher −17,6 MiB e openjdk (8, 17, 21 e 25, que o wrapper do Prism embrulhava)
# −1,8 GiB. Os quatro JDKs saíram porque aqui NINGUÉM declara Java: quem provê é o próprio
# app, que baixa a JRE dele.
#
# ⚠️ O JAVA É DELE, NÃO NOSSO — e declarar Java aqui já foi tentado e NÃO funciona: o app
# só consulta a JRE que ele mesmo gerencia (com três JRE instalados, o log do agent citou
# 18× o java dele e ZERO vez o nosso). Quando aparecer "Java Runtime Environment is missing
# or out of date", a causa NÃO é falta de Java — é o extrator dele perder o bit +x. Quem
# conserta é o `curseforge-fix-java` abaixo; o diagnóstico inteiro está no pacote dele.
#
# Instâncias, mods e login são ESTADO (regra 6 → restic), não declaração:
#   ~/.config/CurseForge/  (config + sessão)   ~/Documents/curseforge/  (instâncias)
#
# ⚠️ POR QUE OS SCHEMES ESTÃO AQUI E NÃO SÃO OPCIONAIS — o app tenta se registrar como
# handler de `curseforge://`/`cfauth://` em RUNTIME (Electron setAsDefaultProtocolClient),
# e isso NUNCA vai funcionar neste sistema: o ~/.config/mimeapps.list é gerenciado pelo
# home-manager e aponta pra /nix/store, que é read-only (regra 14 — o Nix é o dono). Medido
# em 14/08/2026, o log do app diz exatamente isso na largada:
#     [BackgroundController] Failed subscribing app protocol.
#     [LoginService] Failed to register login scheme 'cfauth'. This might create issues
#                    with the login process..
# E o `cfauth://` não é detalhe: é o callback do LOGIN (o app abre o browser e espera o
# redirect de volta). Sem handler, o login volta pro nada. A associação declarativa abaixo
# é o registro que o app não consegue fazer sozinho — o .desktop do pacote já declara os
# três schemes no MimeType, aqui só se diz que ELE é o default.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, lib, ... }:

let
  curseforge = "curseforge.desktop";
in
{
  home.packages = [
    pkgs.curseforge # AppImage oficial reempacotado (./pkgs) — unfree
    # Recalcula version+hash do pkgs/curseforge.nix. No PATH porque quem o chama por nome
    # é o alias `update` (home/shell/zsh.nix) — mesmo arranjo do vscode-bump.
    pkgs.curseforge-bump
    # Conserto do +x da JRE do app (ver o pacote). No PATH porque o download que quebra
    # pode acontecer NO MEIO de uma sessão, e aí a activation abaixo já passou — nesse
    # caso é rodar `curseforge-fix-java` e reabrir o app, sem esperar rebuild.
    pkgs.curseforge-fix-java
  ];

  # A JRE do app é ESTADO (regra 6) e quem a escreve é ele (regra 14) — por isso activation
  # IDEMPOTENTE em vez de gerenciar o arquivo: o Nix não vira dono de nada aqui, só desfaz
  # um estrago conhecido. `writeBoundary` porque o pacote precisa estar no perfil antes.
  home.activation.curseforgeFixJava = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.curseforge-fix-java}
  '';

  # Funde com as associações do home/desktop/xdg.nix (browser) e do media.nix.
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/cfauth" = curseforge; # callback do login — o que mais importa
    "x-scheme-handler/curseforge" = curseforge; # botão "Install" no site do modpack
    "x-scheme-handler/curseforge-checkout" = curseforge; # compra de add-on premium
  };
}
