# AUDIO: PipeWire plus WirePlumber (in place of PulseAudio/JACK, Bluetooth included), with rtkit
# for real-time priority. No note yet: the speaker EQ's reasoning is in its own comments below.
{ lib, ... }:

let
  # Edifier G1500 MAX (USB, 48 kHz/16 bit) curve, tuned by ear in EasyEffects with the speaker in Music mode.
  speaker = "alsa_output.usb-Jieli_Technology_HECATE_G1500_MAX-00.analog-stereo";
  bands = [
    # preamp: a 0 Hz shelf is a flat -5 dB, headroom for the boost
    {
      label = "bq_highshelf";
      freq = 0.0;
      gain = -5.0;
      q = 1.0;
    }
    # the 4" sub cannot play below this, spare its excursion
    {
      label = "bq_highpass";
      freq = 40.0;
      gain = 0.0;
      q = 0.7;
    }
    # more bass, where the sub actually reaches
    {
      label = "bq_lowshelf";
      freq = 100.0;
      gain = 4.0;
      q = 0.7;
    }
    # desk boom and sub/satellite overlap
    {
      label = "bq_peaking";
      freq = 220.0;
      gain = -1.5;
      q = 1.0;
    }
    # takes the edge off the small drivers
    {
      label = "bq_peaking";
      freq = 3000.0;
      gain = -1.5;
      q = 1.4;
    }
    # air
    {
      label = "bq_highshelf";
      freq = 10000.0;
      gain = 1.5;
      q = 0.7;
    }
  ];
  node = i: "eq${toString i}";
in
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

    # Speaker EQ in PipeWire's own filter-chain: no extra app in the path, near-zero CPU.
    # A WirePlumber smart filter: it slots in front of the G1500 only while audio goes there, and is gone otherwise.
    # Mono graph of chained biquads; filter-chain copies it per channel (audio.channels = 2).
    extraConfig.pipewire."90-speaker-eq"."context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "G1500 MAX (EQ)";
          "media.name" = "G1500 MAX (EQ)";
          "filter.graph" = {
            nodes = lib.imap0 (i: b: {
              type = "builtin";
              name = node i;
              inherit (b) label;
              control = {
                Freq = b.freq;
                Q = b.q;
                Gain = b.gain;
              };
            }) bands;
            links = map (i: {
              output = "${node i}:Out";
              input = "${node (i + 1)}:In";
            }) (lib.range 0 (lib.length bands - 2));
          };
          "audio.channels" = 2;
          "audio.position" = [
            "FL"
            "FR"
          ];
          "capture.props" = {
            "node.name" = "effect_input.speaker_eq";
            "media.class" = "Audio/Sink";
            "filter.smart" = true;
            "filter.smart.name" = "speaker-eq";
            "filter.smart.target"."node.name" = speaker; # no speaker plugged in, no EQ anywhere
          };
          "playback.props" = {
            "node.name" = "effect_output.speaker_eq";
            "node.passive" = true; # the chain only runs while something plays
          };
        };
      }
    ];
  };

  # No text-to-speech daemon (graphical-desktop turns it on); drop this line if Discord /tts or a screen reader is ever needed.
  services.speechd.enable = false;
}
