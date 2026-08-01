# ═══════════════════════════════════════════════════════════════════════════
# AGENTE POLKIT — quem mostra o diálogo de senha quando um app GRÁFICO precisa
# de autorização (montar disco de outro usuário, escrever em block device,
# controlar unit do systemd pela GUI…).
#
# LACUNA QUE ISTO FECHA (achada em 01/08/2026): o `polkitd` rodava, mas NÃO havia
# agente nenhum. O daemon sozinho só decide "pode/não pode" pelas regras — quem
# pergunta a senha ao humano é o agente. Sem ele, toda ação que exigisse
# `auth_admin` falhava CALADA: o app pedia autorização, ninguém respondia, e o
# usuário via só "permission denied" sem prompt. Descoberto tentando elevar o
# `woeusbgui`, mas o buraco era geral.
#
# POR QUE hyprpolkitagent: é o do ecossistema Hyprland (Qt6/QML), combina com o
# desktop Qt/Kvantum daqui, e o upstream já entrega um unit systemd pronto — só
# reescrevemos ele em Nix pra ter UM DONO (regra 14) em vez de depender do
# arquivo do pacote.
#
# PEGADINHA CONHECIDA — `graphical-session.target`: em muitos setups Hyprland+NixOS
# esse target fica INATIVO e tudo que depende dele silenciosamente não sobe
# (home-manager#8547). Aqui ele está ativo (o mesmo mecanismo já levanta os
# autostart-* deste repo), então o `WantedBy` padrão funciona. Se um dia os
# autostarts pararem de subir, este agente para junto — e o sintoma vai ser
# "sumiu o prompt de senha", que não parece problema de target.
#
# CONFERIR que está de pé:  systemctl --user status hyprpolkitagent
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  systemd.user.services.hyprpolkitagent = {
    Unit = {
      Description = "Agente de autenticação polkit (Hyprland)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Só faz sentido dentro de uma sessão Wayland — fora dela a unit vira no-op
      # limpo em vez de ficar reiniciando contra um display que não existe.
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      # O binário mora em libexec/, não em bin/ — `getExe` não acha.
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Slice = "session.slice"; # morre junto com a sessão, não vira órfão
      Restart = "on-failure";
      RestartSec = 3;
      TimeoutStopSec = 5;
      # Mesmo freio dos autostart-* (regra do autostart.nix): se entrar em loop, a
      # unit MORRE visível em `systemctl --user --failed` em vez de rodar calada.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
