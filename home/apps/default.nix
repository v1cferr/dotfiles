# The user's GUI apps.
{ ... }:

{
  imports = [
    ./dropbox.nix # the user's sync service (~/Dropbox: Obsidian plus docs)
    ./media.nix # viewers (Gwenview/Okular) plus players (VLC/mpv) plus the default apps
    ./office.nix # ONLYOFFICE: the default for .docx/.xlsx/.pptx/ODF (the MS fonts are in system/)
    ./dolphin.nix # Dolphin: the view mode always "Details" (through activation)
    ./vscode.nix # VS Code: the package plus versioned settings/keybindings (hot-reload through a symlink)
    ./flameshot.nix # ~/.config/flameshot/flameshot.ini (screenshots; the keybind is in hypr.nix)
    ./mangohud.nix # the FPS/temps/usage overlay in games (a declarative config plus a toggle)
    ./openal.nix # ~/.config/alsoft.conf: it forces the pulse backend (sound in OpenAL/HashLink games)
    ./curseforge.nix # Minecraft modpacks: the package (./pkgs) plus the login scheme handler
  ];
}
