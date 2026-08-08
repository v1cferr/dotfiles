# ═══════════════════════════════════════════════════════════════════════════
# DDC/CI — controle de brilho REAL do monitor, pelo cabo de vídeo.
#
# POR QUE ISTO EXISTE: até 08/08/2026 o único "brilho" da máquina era o gamma do
# hyprsunset (SHIFT+VolUp/Down), e gamma NÃO REDUZ LUZ EMITIDA — ele escurece o
# sinal enviado ao painel enquanto o backlight segue no talo. Para cansaço visual
# isso é o remédio errado: a literatura de ergonomia põe REDUZIR BRILHO acima de
# temperatura de cor na ordem de prioridade, e "modo noturno" não substitui brilho
# adequado. Faltava a peça que mexe no backlight de verdade.
#
# COMO FUNCIONA: DDC/CI trafega no mesmo par de fios do EDID, dentro do cabo. O
# `i2c-dev` expõe `/dev/i2c-*` pro userspace e o `ddcutil` fala MCCS com o monitor
# — o mesmo protocolo dos botões do próprio painel. Sem este módulo carregado não
# existe `/dev/i2c-*`, e o ddcutil não tem por onde falar.
#
# ⚠️ SÓ O DP-2 DEVE RESPONDER. Medido em 08/08/2026 nos sysfs dos conectores: o
# `card0-DP-2` expõe 1 barramento i2c, o `card0-HDMI-A-3` expõe ZERO — os dois têm
# EDID de 256 bytes, mas o driver `xe` só registra adaptador i2c no DisplayPort.
# Como o DP-2 é o `my.monitors.primary`, é o que importa. Se o HDMI passar a
# responder num bump de kernel, ótimo; não conte com isso.
#
# ⚠️ NEM TODO MONITOR IMPLEMENTA MCCS mesmo tendo o barramento. `ddcutil detect`
# é o teste; `ddcutil getvcp 10` lê o brilho atual. Se der "No displays found",
# o caminho existe mas o painel não fala o protocolo — e aí o gamma volta a ser
# o único recurso.
#
# GRUPO `i2c`: o módulo do NixOS já libera quem tem SEAT (sessão local), então a
# sessão gráfica funcionaria sem isto. O grupo é o que faz valer também por SSH —
# útil pra ajustar brilho remoto, e pra diagnóstico sem estar na frente da máquina.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  hardware.i2c.enable = true; # carrega o i2c-dev e cria as regras de udev

  users.users.v1cferr.extraGroups = [ "i2c" ];

  # Fica no system/ e não no home/ (regra 4): o pacote só serve com o módulo de
  # kernel e o grupo declarados aqui — separá-los deixaria a ferramenta no perfil
  # do usuário sem o que a faz funcionar.
  environment.systemPackages = [ pkgs.ddcutil ];
}
