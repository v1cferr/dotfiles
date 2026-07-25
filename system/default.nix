# ═══════════════════════════════════════════════════════════════════════════
# SISTEMA — config COMUM a todos os hosts (machine-agnostic). Organizado por
# CATEGORIA (subpasta com seu próprio default.nix). O específico de cada máquina
# (hostname, discos, kernel, stateVersion) vive em hosts/<host>/default.nix.
# Novo módulo? cria system/<categoria>/<tema>.nix e adiciona no default.nix da
# categoria. Categoria nova? cria system/<categoria>/ e adiciona 1 linha aqui.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./core # Nix/flakes, boot, usuários, segredos, locale
    ./hardware # CPU/microcode, GPU (Arc B580), áudio (PipeWire), fontes
    ./net # NetworkManager, SSH exposto, fail2ban, DDNS
    ./desktop # LightDM, Hyprland, xkb, portal (dark mode), gnome-keyring
    ./services # backup (restic), hooks (Claude Code), mídia (Jellyfin/qBit), IA (Ollama/duo)
    ./packages.nix # environment.systemPackages (apps/ferramentas de sistema)
  ];
}
