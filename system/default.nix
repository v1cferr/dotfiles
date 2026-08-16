# THE SYSTEM: the config COMMON to every host, by CATEGORY. What is per-machine (hostname, disks,
# kernel, stateVersion) lives in hosts/<host>/. A new category = a folder plus 1 line here.
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
