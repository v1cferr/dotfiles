# THE SYSTEM: the config COMMON to every host (machine-agnostic). Organized by CATEGORY (a
# subfolder with its own default.nix). What is specific to each machine (hostname, disks, kernel,
# stateVersion) lives in hosts/<host>/default.nix.
# A new module? Create system/<category>/<topic>.nix and add it to the category's default.nix.
# A new category? Create system/<category>/ and add 1 line here.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  imports = [
    ./core # Nix/flakes, boot, users, secrets, locale
    ./hardware # CPU/microcode, the GPU (Arc B580), audio (PipeWire), fonts
    ./net # NetworkManager, the exposed SSH, fail2ban, DDNS
    ./desktop # LightDM, Hyprland, xkb, the portal (dark mode), gnome-keyring
    ./services # backup (restic), hooks (Claude Code), media (Jellyfin/qBit), AI (Ollama/duo)
    ./gaming # Steam plus Proton-GE plus gamemode (a system-level FHS-wrap/firewall)
    ./packages.nix # environment.systemPackages (system apps/tools)
  ];
}
