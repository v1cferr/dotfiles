# Apps GUI de usuário SEM config declarativa própria (só o binário) — agrupados
# numa lista, em vez de 1 arquivo por app (idiomático p/ pacotes sem programs.*).
# Apps COM config/módulo próprio ficam no seu arquivo (dolphin, flameshot, media,
# mangohud). unfree ok (allowUnfree herdado do system).
{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # ── Navegadores ──
    librewolf # Firefox hardened (privacidade)
    google-chrome # Chrome (unfree; compatibilidade/DevTools)
    inputs.zen-browser.packages.${pkgs.system}.default # Zen (flake; ver flake.nix)

    # ── Comunicação ──
    discord # voz/chat (unfree; expõe o socket IPC pro Rich Presence do Claude Code)

    # ── Notas / mídia ──
    obsidian # notas em Markdown (cofre local; unfree)
    spotify # música (unfree)

    # VS Code: override --password-store=gnome-libsecret — no Hyprland o Electron não
    # autodetecta o backend de secret (XDG_CURRENT_DESKTOP não é GNOME/KDE) e mostra
    # "couldn't identify OS keyring"; a flag força o gnome-keyring (libsecret).
    # Extensões/settings ficam com o Settings Sync (conta), NÃO com o nix.
    (vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })

    # Torrent GUI (uso manual) — separado do serviço headless (system/services/qbittorrent.nix).
    qbittorrent

    # Bitwarden desktop (GUI Electron). Electron 39 EOL liberado em
    # permittedInsecurePackages (system/core/core.nix) — os dois canais fixam o mesmo.
    bitwarden-desktop
  ];
}
