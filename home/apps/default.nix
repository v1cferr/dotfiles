# Apps GUI de usuário.
{ ... }:

{
  imports = [
    ./dropbox.nix # serviço de sync do usuário (~/Dropbox: Obsidian + docs)
    ./media.nix # visualizadores (Gwenview/Okular) + players (VLC/mpv) + apps padrão
    ./office.nix # ONLYOFFICE: default de .docx/.xlsx/.pptx/ODF (fontes MS no system/)
    ./dolphin.nix # Dolphin: view mode sempre "Detalhes" (via activation)
    ./flameshot.nix # ~/.config/flameshot/flameshot.ini (screenshot; keybind em hypr.nix)
    ./mangohud.nix # overlay de FPS/temps/uso nos jogos (config declarativa + toggle)
    ./openal.nix # ~/.config/alsoft.conf: força backend pulse (som dos jogos OpenAL/HashLink)
  ];
}
