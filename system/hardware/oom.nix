# OOM — evita o TRAVAMENTO por falta de RAM (ex.: Chrome/Electron comendo tudo).
#
# Companheiro do zram (hardware.nix): quando a RAM aperta, o zram comprime; quando
# nem isso segura, alguém tem que morrer ANTES do kernel congelar a máquina.
#
# Camadas: o systemd-oomd (ligado por padrão no NixOS) é PSI/cgroup e reage devagar
# — num Hyprland os apps não ficam em cgroups monitorados, então ele deixa passar.
# O earlyoom é %-based e MATA O MAIOR PROCESSO cedo (previne o freeze de 30-60s).
# Os dois coexistem: earlyoom é o guarda rápido, oomd o backstop de cgroup.
{ ... }:

{
  services.earlyoom = {
    enable = true;
    # Defaults testados do earlyoom (10%/10%): SIGTERM quando RAM livre < 10% E swap
    # livre < 10% (SIGKILL na metade: 5%/5%). Agir CEDO (10%) previne melhor o freeze
    # que esperar 5%. Como o swap é 100% zram (mora na RAM), a métrica de swap é pouco
    # confiável — por isso apoiamos no threshold de RAM. Se ainda travar, sobe o de RAM.
    freeMemThreshold = 10; # RAM livre < 10% → SIGTERM no maior processo
    freeSwapThreshold = 10; # e swap (zram) livre < 10%
    enableNotifications = true; # avisa no desktop (mako) qual processo foi morto e por quê

    # comm (nome, até 15 chars) casado por regex estendida:
    extraArgs = [
      # PREFERE matar (os comilões descartáveis, fáceis de reabrir). NOTA: editores
      # (code/obsidian) FORA daqui de propósito — perder trabalho não salvo dói mais
      # que um navegador; que morram o Chrome/Discord antes do VSCode.
      "--prefer"
      "^(chrome|chromium|firefox|librewolf|zen|electron|spotify|Discord)"
      # NUNCA mata (compositor, sessão, áudio e acesso remoto — perder isso = tela travada/sem SSH):
      "--avoid"
      "^(Hyprland|waybar|hyprlock|hypridle|sshd|systemd|dbus-broker|pipewire|wireplumber|mako)$"
    ];
  };
}
