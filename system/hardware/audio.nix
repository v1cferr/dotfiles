# AUDIO: PipeWire (it replaces PulseAudio/JACK) ───────────────────────────────
# The default sound stack on modern NixOS plus Wayland. WirePlumber (the session manager) comes
# along and handles the routing, Bluetooth audio (A2DP/HFP) included, with no need for an extra
# module the way old PulseAudio did. rtkit gives the server real-time priority (which avoids
# xruns/crackles).
# Control: `wpctl` (a CLI, it comes with wireplumber), `pavucontrol` (a GUI) and, in Hyprland's
# keybinds, `pamixer` (volume) plus `playerctl` (play/pause/next).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  security.rtkit.enable = true;
  services.pulseaudio.enable = false; # PipeWire takes PulseAudio's place
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # 32-bit apps (games/Wine) play sound
    pulse.enable = true; # compatibility: apps that speak PulseAudio (most of them)
    jack.enable = true; # compatibility: pro-audio apps that speak JACK
    wireplumber.enable = true;
  };
}
