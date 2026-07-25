# ═══════════════════════════════════════════════════════════════════════════
# ÁUDIO: PipeWire (substitui PulseAudio/JACK) ─────────────────────────────────
# Stack de som padrão no NixOS moderno + Wayland. O WirePlumber (session
# manager) vem junto e cuida do roteamento — inclusive de áudio Bluetooth
# (A2DP/HFP), sem precisar de módulo extra como no PulseAudio antigo. O rtkit
# dá prioridade de tempo-real ao servidor (evita xruns/estalos).
# Controle: `wpctl` (CLI, vem no wireplumber), `pavucontrol` (GUI) e, nos
# keybinds do Hyprland, `pamixer` (volume) + `playerctl` (play/pause/next).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  security.rtkit.enable = true;
  services.pulseaudio.enable = false; # o PipeWire assume o lugar do PulseAudio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # apps 32-bit (jogos/Wine) tocam som
    pulse.enable = true; # compat: apps que falam PulseAudio (a maioria)
    jack.enable = true; # compat: apps pro-audio que falam JACK
    wireplumber.enable = true;
  };
}
