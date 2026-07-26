# ═══════════════════════════════════════════════════════════════════════════
# OpenAL — força o backend PulseAudio p/ jogos que usam OpenAL-soft (gera
# ~/.config/alsoft.conf, lido por QUALQUER OpenAL-soft, inclusive o embutido no
# jogo). Sem isto, o OpenAL 1.18.2 que vem junto dos jogos HashLink/Heaps
# (Northgard, Dead Cells, Evoland…) não tem backend `pipewire` (só chegou no
# 1.20+) e, dentro do sandbox do Steam runtime, cai num device ALSA errado →
# fica MUDO. `pulse` conecta no socket do pipewire-pulse → som no sink padrão.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  xdg.configFile."alsoft.conf".text = ''
    [general]
    drivers = pulse
  '';
}
