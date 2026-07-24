# ═══════════════════════════════════════════════════════════════════════════
# SISTEMA — config COMUM a todos os hosts (machine-agnostic), só a lista de
# imports. Cada assunto vive no seu módulo temático (system/<tema>.nix). O
# específico de cada máquina (hostname, discos, kernel, stateVersion) vive em
# hosts/<host>/default.nix. Novo tema? cria system/<tema>.nix e adiciona aqui.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./core.nix # Nix/flakes, nixpkgs (unfree/inseguros), nix-ld, locale/idioma
    ./boot.nix # bootloader UEFI (systemd-boot). GRUB+minegrub pré-configurado em boot-grub.nix — trocar aqui EM CASA
    ./network.nix # NetworkManager, SSH exposto, fail2ban, DNS dinâmico, no-sleep
    ./hardware.nix # CPU/microcode, firmware, zram, Bluetooth, udisks2
    ./gpu.nix # driver de vídeo: Intel Arc B580 (xe + Mesa, sem CUDA)
    ./audio.nix # PipeWire + rtkit
    ./desktop.nix # LightDM, Hyprland, xkb, portal (dark mode), gnome-keyring
    ./fonts.nix # JetBrainsMono Nerd Font (padrão mono/sans/serif)
    ./users.nix # zsh como shell de login + a conta v1cferr
    ./packages.nix # environment.systemPackages (apps/ferramentas de sistema)
    ./restic.nix # backup cifrado do estado do usuário (repo no HDD por ora)
    ./secrets.nix # base do sops + sops.secrets do Bitwarden + comando sync-secrets
    ./media/jellyfin.nix # servidor de mídia Jellyfin (nativo, systemd, biblioteca em /srv/media)
    ./media/qbittorrent.nix # cliente de download (Web UI 8080; grava em /srv/media/torrents)
    ./ai/ollama.nix # runtime de IA local (CPU); solver do duo-streak-daemon
    ./ai/duo.nix # stack do duo-streak-daemon (compose declarativo; auto-ativa com o segredo)
  ];
}
