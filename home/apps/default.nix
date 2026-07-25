# Apps GUI de usuário.
{ ... }:

{
  imports = [
    ./discord.nix # cliente Discord (voz/chat; expõe o socket IPC pro Rich Presence)
    ./dropbox.nix # serviço de sync do usuário (~/Dropbox: Obsidian + docs)
    ./media.nix # visualizadores (Gwenview/Okular) + players (VLC/mpv) + apps padrão
    ./dolphin.nix # Dolphin: view mode sempre "Detalhes" (via activation)
    ./flameshot.nix # ~/.config/flameshot/flameshot.ini (screenshot; keybind em hypr.nix)
    ./mangohud.nix # overlay de FPS/temps/uso nos jogos (config declarativa + toggle)
  ];
}
