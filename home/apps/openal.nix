# OpenAL: it forces the PulseAudio backend for games that use OpenAL-soft (it generates
# ~/.config/alsoft.conf, read by ANY OpenAL-soft, the one bundled with the game included). Without
# this, the OpenAL 1.18.2 that ships with the HashLink/Heaps games (Northgard, Dead Cells,
# Evoland…) has no `pipewire` backend (that only arrived in 1.20+) and, inside the Steam runtime's
# sandbox, falls into the wrong ALSA device and goes MUTE. `pulse` connects to the pipewire-pulse
# socket, so sound comes out on the default sink.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  xdg.configFile."alsoft.conf".text = ''
    [general]
    drivers = pulse
  '';
}
