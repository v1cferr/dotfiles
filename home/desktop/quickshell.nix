# QUICKSHELL — o shell/bar em QML (bar, OSD, mídia, notificações), substituindo a
# waybar. O binário vem do FLAKE oficial (inputs.quickshell → sempre a última;
# bump com `nix flake update quickshell`).
#
# HOT-RELOAD (o motivo de ser assim): a config QML mora no REPO
# (home/desktop/quickshell/) e é linkada por mkOutOfStoreSymlink — um symlink pro
# arquivo MUTÁVEL, não pra store read-only. Assim o Quickshell recarrega o QML AO
# VIVO ao salvar (sem rebuild), e os arquivos seguem versionados no git (portável:
# outra máquina clona o repo no mesmo caminho e funciona). É um desvio consciente
# da regra 3 (não é symlink puro da store), padrão da comunidade p/ ricing de QML.
{ pkgs, config, inputs, ... }:

let
  # qs-restart: mata e sobe o Quickshell de novo. Necessário porque o hot-reload NÃO
  # reaplica delegate de Repeater (ws-pills, notificações) — editar o QML desses não
  # basta, precisa reiniciar o processo.
  #
  # POR QUE UM SCRIPT e não `qs kill; sleep 0.3; qs &` direto no bind: regra 7 (lógica
  # no build, bind = 1 comando) e regra 15 (dono explícito) — subir via `hyprctl
  # dispatch` faz o COMPOSITOR ser o pai, o mesmo dono do exec-once do autostart.lua,
  # em vez de o processo ser reparenteado ao init. De quebra o script funciona de um
  # shell fora da sessão, por causa do `-i 0`.
  #
  # CORREÇÃO (30/07): a versão anterior deste comentário afirmava que a forma antiga
  # NÃO reiniciava nada. Era FALSO. A evidência ("Quickshell com 5h de uptime depois de
  # apertar SUPER+ESCAPE") tinha causa banal: o usuário apertou SUPER+SPACE. Testada
  # depois, a forma antiga reinicia sim — o processo só termina com ppid=1 (systemd),
  # que é daemonização normal e sobrevive. Ou seja, isto é MELHORIA de arquitetura, não
  # correção de bug. Fica registrado porque inferir mecanismo a partir de uma observação
  # com explicação mais simples é justamente o erro que a regra 14 manda evitar.
  qsRestart = pkgs.writeShellApplication {
    name = "qs-restart";
    runtimeInputs = [
      inputs.quickshell.packages.${pkgs.system}.default
      pkgs.hyprland
      pkgs.coreutils
    ];
    text = ''
      qs kill >/dev/null 2>&1 || true # sem instância rodando, o kill falha e está tudo bem
      sleep 0.3
      # `-i 0` acha a instância sem HYPRLAND_INSTANCE_SIGNATURE → funciona também por SSH.
      hyprctl -i 0 dispatch 'hl.dsp.exec_cmd("qs")'
    '';
  };
in
{
  home.packages = [
    inputs.quickshell.packages.${pkgs.system}.default # `qs` / `quickshell`
    pkgs.lm_sensors # `sensors` — CPU temp lido pelo bar/Bar.qml
    qsRestart # `qs-restart` — usado pelo bind SUPER+ESCAPE (keybinds.lua)
  ];

  # ~/.config/quickshell → arquivo real no repo (mutável) = hot-reload.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/quickshell";
}
