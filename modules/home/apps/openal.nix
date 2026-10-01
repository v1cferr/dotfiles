# OpenAL: it forces the `pulse` backend, without which the OpenAL 1.18.2 bundled with the
# HashLink games goes MUTE inside the Steam runtime. The why: docs/notes/apps/apps-and-mime.md
{ ... }:

{
  xdg.configFile."alsoft.conf".text = ''
    [general]
    drivers = pulse
  '';
}
