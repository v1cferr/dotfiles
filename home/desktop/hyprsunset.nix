# Filtro de luz azul do ecossistema Hyprland (hyprsunset). Escolhido no lugar de
# gammastep/wlsunset porque age via CTM no compositor (hyprland-ctm-control-v1),
# NÃO por shader — então NÃO aparece em screenshot/gravação (importante: uso o
# Flameshot direto). Docs: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
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
      # gamma = brilho percebido (1.0 = normal; <1 escurece). Auto-dim SÓ de noite:
      # dia e início de noite ficam em brilho cheio (pode estar trabalhando); das 22h
      # em diante escurece de leve até 0.8 (piso), reduzindo o cansaço no escuro, e
      # volta ao normal de manhã. Perfil sem gamma volta a 1.0 (cada perfil zera os outros).
      profile = [
        {
          time = "0:00";
          temperature = 2000;
          gamma = 0.8;
        } # madrugada: quente + escuro
        {
          time = "6:00";
          temperature = 3000;
          gamma = 0.9;
        } # amanhecer: esfria + clareia
        {
          time = "7:00";
          temperature = 4000;
          gamma = 1.0;
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
          gamma = 0.9;
        } # pré-sono: reduz azul + dim leve
        {
          time = "23:00";
          temperature = 2500;
          gamma = 0.85;
        }
        {
          time = "23:30";
          temperature = 2200;
          gamma = 0.8;
        } # transição final p/ a madrugada
      ];
    };
  };
}
