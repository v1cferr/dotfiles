# AUDIO: PipeWire plus WirePlumber (it replaces PulseAudio/JACK, Bluetooth audio included).
# rtkit gives it real-time priority, which is what avoids xruns and crackling.
# Speech Dispatcher (text-to-speech for the browser) is pinned to espeak-ng only.
{ config, ... }:

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

  # A config with no AddModule probes every sd_* binary and leaves the failed ones defunct.
  services.speechd.config = ''
    LogLevel 3
    LogDir "default"
    DefaultVolume 100
    SymbolsPreproc "char"
    SymbolsPreprocFile "gender-neutral.dic"
    SymbolsPreprocFile "font-variants.dic"
    SymbolsPreprocFile "symbols.dic"
    SymbolsPreprocFile "emojis.dic"
    SymbolsPreprocFile "orca.dic"
    SymbolsPreprocFile "orca-chars.dic"
    AddModule "espeak-ng" "sd_espeak-ng" "espeak-ng.conf"
    DefaultModule espeak-ng
  '';
  environment.etc."speech-dispatcher/modules/espeak-ng.conf".source =
    "${config.services.speechd.package}/etc/speech-dispatcher/modules/espeak-ng.conf";
}
