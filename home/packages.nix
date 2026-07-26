# ═══════════════════════════════════════════════════════════════════════════
# PACOTES DO USUÁRIO (home-manager) — a lista CENTRAL. É AQUI que você adiciona
# um app/CLI novo SEM config própria (espelha o system/packages.nix). Apps COM
# config declarativa vivem no seu módulo (programs.* ou apps/desktop/shell):
# kitty, git, dolphin, flameshot, media, waybar, tema, helpers do Hyprland. unfree
# ok (allowUnfree herdado do system).
#
# `pkgs.foo` = base estável (26.05); `pkgs.unstable.foo` = canal bleeding-edge.
# ═══════════════════════════════════════════════════════════════════════════
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

    # ── Editor / dev ──
    # VS Code: override --password-store=gnome-libsecret — no Hyprland o Electron não
    # autodetecta o backend de secret e mostra "couldn't identify OS keyring"; a flag
    # força o gnome-keyring. Extensões/settings = Settings Sync (conta), NÃO nix.
    (vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })

    # ── Torrent / senhas ──
    qbittorrent # torrent GUI (uso manual) — separado do serviço headless (system/services/qbittorrent.nix)
    bitwarden-desktop # GUI Electron (Electron 39 EOL liberado em system/core/core.nix)
    bitwarden-cli # `bw` — consultar/scriptar o cofre no terminal

    # ── Jogos / emuladores (bottles/ROMs/instâncias são ESTADO → backup, regra 6) ──
    (bottles.override { removeWarningPopup = true; }) # Wine/Proton FHS-wrapped; popup "Unsupported" silenciado
    rpcs3 # emulador PS3 (Uncharted 1/2/3); firmware + jogos = estado, você provê
    prismlauncher # Minecraft nativo p/ modpacks (vem wrapped com os JDKs 8/17/21)

    # ── CLIs ──
    gh # GitHub CLI (auth/push via HTTPS + token)
    unstable.fastfetch # resumo do sistema (bleeding-edge: hardware/versões novas)
    unstable.claude-code # este assistente de código (bleeding-edge — evolui rápido)
    unstable.yt-dlp # baixa vídeo/áudio (unstable pq quebra quando os sites mudam)
  ];
}
