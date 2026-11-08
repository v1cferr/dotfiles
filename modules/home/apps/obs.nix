# OBS STUDIO: recording and streaming scenes, through Home Manager's module (idiomatic).
# Screen capture goes through the portal (PipeWire) and the Arc encoders are built in. No note: this is all of it.
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs.obs-studio-plugins)
    obs-pipewire-audio-capture
    wlrobs
    ;
in
{
  programs.obs-studio = {
    enable = true;
    plugins = [
      wlrobs # a wlr-screencopy source: one Hyprland output with no portal picker each time
      obs-pipewire-audio-capture # per-app audio sources (Discord apart from the game, say)
    ];
  };
}
