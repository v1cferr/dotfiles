# Filtro de luz azul do ecossistema Hyprland (hyprsunset). Escolhido no lugar de
# gammastep/wlsunset porque age via CTM no compositor (hyprland-ctm-control-v1),
# NÃO por shader — então NÃO aparece em screenshot/gravação (importante: uso o
# Flameshot direto). Docs: https://wiki.hypr.land/Hypr-Ecosystem/hyprsunset/
#
# O módulo services.hyprsunset sobe um SERVIÇO systemd --user (dispensa exec-once)
# e gera ~/.config/hypr/hyprsunset.conf a partir de `settings`. Os `profile` trocam
# a temperatura por horário do relógio sozinhos; os keybinds F9 (home/hypr.nix) são
# só override manual pontual via `hyprctl hyprsunset`. Schedule herdado dos dotfiles
# do Arch. Kelvin: 6500=dia neutro · 4000=noite · 3000=noite avançada · 2000=madrugada.
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
        { time = "0:00"; temperature = 2000; gamma = 0.8; } # madrugada: quente + escuro
        { time = "6:00"; temperature = 3000; gamma = 0.9; } # amanhecer: esfria + clareia
        { time = "7:00"; temperature = 4000; gamma = 1.0; } # manhã: brilho normal de volta
        { time = "8:00"; identity = true; } # dia (8h–17h30): neutro, sem filtro, brilho cheio
        { time = "17:30"; temperature = 6000; } # fim de tarde: 1º aquecimento (sem dim ainda)
        { time = "18:00"; temperature = 5500; }
        { time = "19:00"; temperature = 5000; }
        { time = "20:00"; temperature = 4500; }
        { time = "21:00"; temperature = 4000; }
        { time = "22:00"; temperature = 3500; gamma = 0.9; } # pré-sono: reduz azul + dim leve
        { time = "23:00"; temperature = 3000; gamma = 0.85; }
        { time = "23:30"; temperature = 2500; gamma = 0.8; } # transição final p/ a madrugada
      ];
    };
  };
}
