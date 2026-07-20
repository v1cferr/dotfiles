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
      profile = [
        { time = "0:00"; temperature = 2000; } # madrugada: bem quente p/ o sono
        { time = "6:00"; temperature = 3000; } # amanhecer: começa a esfriar
        { time = "7:00"; temperature = 4000; } # manhã inicial: ainda morno
        { time = "8:00"; identity = true; } # dia (8h–17h30): cores neutras, sem filtro
        { time = "17:30"; temperature = 6000; } # fim de tarde: 1º aquecimento leve
        { time = "18:00"; temperature = 5500; }
        { time = "19:00"; temperature = 5000; }
        { time = "20:00"; temperature = 4500; }
        { time = "21:00"; temperature = 4000; }
        { time = "22:00"; temperature = 3500; } # pré-sono: reduz azul
        { time = "23:00"; temperature = 3000; }
        { time = "23:30"; temperature = 2500; } # transição final p/ a madrugada
      ];
    };
  };
}
