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
    enableNotifications = true; # avisa no desktop qual processo foi morto e por quê

    # O earlyoom casa `comm` — o campo do KERNEL, truncado em 15 chars — por regex
    # estendida. TRÊS armadilhas, todas medidas nesta máquina em 05/08/2026:
    #
    #   1. WRAPPER DO NIXPKGS muda o nome. `wrapProgram` deixa o script com o nome
    #      original e o ELF real como `.X-wrapped`; quem roda é o ELF, então o comm é
    #      `.Hyprland-wrapp` e `.quickshell-wra` (cortados no 15º char) — NUNCA
    #      "Hyprland". Daí o `[.]?` e o fim SEM `$`: casa embrulhado e cru, e sobrevive
    #      ao dia que um pacote passar (ou deixar) de ser embrulhado.
    #   2. ÂNCORA `$` + nome exato = falso senso de proteção. A lista antiga era
    #      `^(Hyprland|waybar|…|mako)$` e casava 5 de 10 contra os processos vivos: o
    #      COMPOSITOR ficava de fora pelo motivo 1, e `waybar`/`mako` eram fantasmas
    #      (saíram na migração pro Quickshell). Ou seja, o comentário prometia
    #      "compositor nunca morre" e o efeito era o oposto do escrito.
    #   3. `[.]` e NÃO `\.` — a barra invertida NÃO CHEGA. O módulo do nixpkgs entrega
    #      os args por `Environment=EARLYOOM_ARGS=…`, e o systemd descarta `\.` como
    #      escape inválido. Escrito `"^\\.?"`, o earlyoom logava
    #      `regex '^.?(Hyprland|…)'` — sem a barra. Ainda funcionava (`.?` = um char
    #      qualquer opcional, e sobra-casar no --avoid erra pro lado seguro), mas o
    #      comentário passava a mentir. Classe de caractere não tem barra pra perder.
    #      CONFERIR sempre no que o daemon PARSEOU, nunca no .nix:
    #        journalctl -u earlyoom | grep 'avoid killing'
    extraArgs = [
      # PREFERE matar (os comilões descartáveis, fáceis de reabrir). NOTA: editores
      # (code/obsidian) FORA daqui de propósito — perder trabalho não salvo dói mais
      # que um navegador; que morram o Chrome/Discord antes do VSCode.
      "--prefer"
      "^(chrome|chromium|firefox|librewolf|zen|electron|spotify|Discord)"
      # NUNCA mata: compositor e shell (tela travada), áudio, sessão e SSH (sem resgate).
      # quickshell entra no lugar da waybar — hoje ele é barra, OSD E daemon de notificação.
      "--avoid"
      "^[.]?(Hyprland|quickshell|hyprlock|hypridle|hyprpaper|sshd|systemd|dbus-broker|pipewire|wireplumber)"
    ];
  };
}
