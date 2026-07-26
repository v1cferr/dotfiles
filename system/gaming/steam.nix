# ═══════════════════════════════════════════════════════════════════════════
# STEAM — cliente + runtime Proton (nível-sistema, obrigatório: programs.steam
# faz o FHS-wrap do cliente e injeta o steam-runtime). Unfree já liberado
# (core.nix) e libs 32-bit já ligadas p/ Wine/Proton (gpu.nix: enable32Bit).
#
# Jogos/prefixos são ESTADO (~/.local/share/Steam) → fora do backup restic, como
# o Bottles (regra 6). O overlay MangoHud (home/apps) injeta via `mangohud %command%`
# nas opções de inicialização do jogo. gamemode: use `gamemoderun %command%` (ou os
# dois juntos) p/ o boost de governador/CPU enquanto joga.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Steam Remote Play / Link (streaming p/ outros dispositivos)
    localNetworkGameTransfers.openFirewall = true; # baixa jogos de outro PC Steam da LAN em vez da internet
    extraCompatPackages = [ pkgs.proton-ge-bin ]; # Proton-GE: compat melhor que o Proton oficial (fixes/codecs)
  };

  # Feral GameMode: governador performance + prioridade de I/O enquanto o jogo
  # roda (ativado por `gamemoderun %command%`). Ganho de CPU sem overclock.
  programs.gamemode.enable = true;
}
