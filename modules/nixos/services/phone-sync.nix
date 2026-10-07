# PHONE SYNC: Syncthing pulls the phone's DCIM into a plain folder, so Dolphin browses LOCAL files.
# Receive-only and deletes ignored: an accumulating copy, NOT a mirror. See docs/notes/services/phone-sync.md
{ config, lib, ... }:

let
  cfg = config.my.phoneSync;
  home = config.users.users.v1cferr.home;
in
{
  options.my.phoneSync = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "${home}/Pictures/M51";
      description = "Where the phone's DCIM lands. An SSOT read by Dolphin's bookmark (rule 11).";
    };

    deviceId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The phone's Syncthing Device ID. Not a secret; null keeps the folder unshared (inert).";
    };
  };

  config = lib.mkIf config.my.services.phone-sync {
    services.syncthing = {
      enable = true;
      user = "v1cferr";
      group = "users";
      dataDir = home;
      configDir = "${home}/.config/syncthing";
      # 22000 TCP/UDP plus 21027 UDP (discovery), so the phone connects DIRECTLY on the LAN.
      openDefaultPorts = true;

      # Nix owns devices and folders: anything added in the GUI is dropped on the next start.
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        options.urAccepted = -1; # no usage reporting, and no prompt asking for it
        devices = lib.optionalAttrs (cfg.deviceId != null) {
          m51.id = cfg.deviceId;
        };
        folders.m51-dcim = {
          label = "M51 DCIM";
          path = cfg.local;
          type = "receiveonly"; # the phone is the only source; a local edit never travels back
          ignoreDelete = true; # deleting on the phone (to free space) keeps the copy here
          devices = lib.optional (cfg.deviceId != null) "m51";
          # Android's thumbnail cache and the gallery's 30-day trash never come over.
          ignorePatterns = [
            "(?d).thumbnails"
            "(?d).trashed-*"
          ];
        };
      };
    };

    systemd.tmpfiles.rules = [ "d ${cfg.local} 0755 v1cferr users -" ];
  };
}
