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
    freeMemThreshold = 5; # RAM livre < 5% → SIGTERM no maior processo (killThreshold menor = SIGKILL)
    freeSwapThreshold = 10; # e swap (zram) livre < 10% — junto com a RAM, evita matar cedo demais
    enableNotifications = true; # avisa no desktop (mako) qual processo foi morto e por quê

    # comm (nome, até 15 chars) casado por regex estendida:
    extraArgs = [
      # PREFERE matar (os comilões que costumam disparar):
      "--prefer"
      "^(chrome|chromium|firefox|librewolf|zen|electron|code|obsidian|spotify|Discord)"
      # NUNCA mata (compositor, sessão, áudio e acesso remoto — perder isso = tela travada/sem SSH):
      "--avoid"
      "^(Hyprland|waybar|hyprlock|hypridle|sshd|systemd|dbus-broker|pipewire|wireplumber|mako)$"
    ];
  };
}
