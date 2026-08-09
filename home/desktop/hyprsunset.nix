# Filtro de luz azul do ecossistema Hyprland (hyprsunset). Age via CTM no compositor
# (hyprland-ctm-control-v1), então NÃO aparece em screenshot/gravação — importante
# porque uso o Flameshot direto. Docs: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
#
# ⚠️ CORREÇÃO (08/08/2026): este bloco dizia que a escolha foi "no lugar de
# gammastep/wlsunset porque não é shader". O argumento estava torto — gammastep e
# wlsunset TAMBÉM não usam shader. Quem usa é o hyprshade, e é contra ELE que o wiki
# do Hyprland recomenda o hyprsunset ("preferred to screen shaders as it will not be
# captured via recording/screenshots"). O motivo real de preferir aos outros dois é
# ser nativo do protocolo do Hyprland, não a questão do shader.
#
# ⚠️ OS 13 PERFIS NÃO SÃO EXCESSO. Verificado no código do hyprsunset 0.3.3: ZERO
# ocorrências de transition/interpolate/gradual, e a issue "Graduated transition"
# segue ABERTA. Ele salta seco no horário de cada perfil. Degrau pequeno e frequente
# é a ÚNICA forma de obter curva suave numa ferramenta que só sabe saltar — se um dia
# ele interpolar, isto colapsa pra 3 perfis (ver docs/ideias.md).
#
# O módulo services.hyprsunset sobe um SERVIÇO systemd --user (dispensa exec-once)
# e gera ~/.config/hypr/hyprsunset.conf a partir de `settings`. Os `profile` trocam
# a temperatura por horário do relógio sozinhos; os keybinds F9 (home/hypr.nix) são
# só override manual pontual via `hyprctl hyprsunset`.
# Kelvin: 6500=dia neutro · 4000=noite · 3000=noite avançada · 2000=madrugada.
#
# A NOITE É AGRESSIVA DE PROPÓSITO (06/08/2026, reescrita do schedule herdado do
# Arch): trabalho o dia inteiro em OUTRO PC sem filtro, então quando chego às 18h
# o olho já vem castigado e não dá pra tratar 18h como "início de noite leve". O
# schedule antigo só descia de 500 em 500K e chegava em 5500K às 18h — perto do
# neutro, ou seja, alívio real só às 22h, 4h depois de chegar. Agora o maior
# degrau da curva é justamente às 18h (5500→4200), e às 19h já está em 3500K.
# ⚠️ Abaixo de ~3200K a cor fica visivelmente laranja e ESTRAGA filme/jogo/foto:
# o escape hatch é SUPER+SHIFT+F9 (`hyprctl hyprsunset identity` = filtro OFF), e
# o próximo perfil do relógio retoma a curva sozinho. Se atrapalhar demais, o
# ajuste é subir SÓ o degrau das 18h/18:30 — não achatar a curva inteira.
{ ... }:

{
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 150; # teto do gamma em % (default 100); folga p/ ajuste via IPC

      # Perfis por horário (transição suave ao longo do dia). identity = filtro OFF.
      #
      # ⚠️ SEM `gamma` NOS PERFIS desde 08/08/2026, e a razão é uma interação: o
      # hyprsunset NÃO SABE mirar uma saída específica (procurei `output`/`monitor`/
      # `display` no código-fonte: ZERO ocorrências — ele aplica CTM em todas de uma
      # vez). Com o backlight real do DP-2 agora vindo do DDC/CI
      # (../desktop/brightness.nix), manter o auto-dim aqui daria dimming DUPLO no
      # monitor bom (backlight 32% × gamma 0.9) pra entregar um alívio fraco na TV.
      # Cada tela passa a ser tratada pela ferramenta certa:
      #   DP-2 (LG ULTRAGEAR) → backlight de verdade, via DDC/CI
      #   HDMI-A-3 (LG TV)    → ajuste de backlight no controle remoto dela (não fala DDC/CI)
      #
      # O `max-gamma` abaixo FICA: os keybinds SHIFT+VolUp/Down seguem ajustando gamma
      # por IPC, agora como retoque fino manual em vez de curva automática.
      profile = [
        {
          time = "0:00";
          temperature = 2000;
        } # madrugada: quente + escuro
        {
          time = "6:00";
          temperature = 3000;
        } # amanhecer: esfria + clareia
        {
          time = "7:00";
          temperature = 4000;
        } # manhã: brilho normal de volta
        {
          time = "8:00";
          identity = true;
        } # dia (8h–17h30): neutro, sem filtro, brilho cheio
        {
          time = "17:30";
          temperature = 5500;
        } # fim de tarde: 1º aquecimento (sem dim ainda)
        {
          time = "18:00";
          temperature = 4200;
        } # CHEGADA DO TRABALHO: maior degrau da curva, é aqui que o alívio começa
        {
          time = "18:30";
          temperature = 3800;
        }
        {
          time = "19:00";
          temperature = 3500;
        }
        {
          time = "20:00";
          temperature = 3200;
        }
        {
          time = "21:00";
          temperature = 3000;
        }
        {
          time = "22:00";
          temperature = 2800;
        } # pré-sono: reduz azul + dim leve
        {
          time = "23:00";
          temperature = 2500;
        }
        {
          time = "23:30";
          temperature = 2200;
        } # transição final p/ a madrugada
      ];
    };
  };
}
