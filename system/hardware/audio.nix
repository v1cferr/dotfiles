# AUDIO: PipeWire plus WirePlumber (it replaces PulseAudio/JACK, Bluetooth audio included).
# rtkit gives it real-time priority, which is what avoids xruns and crackling.
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

  # No text-to-speech daemon (graphical-desktop turns it on); drop this line if Discord /tts or a screen reader is ever needed.
  services.speechd.enable = false;
}
