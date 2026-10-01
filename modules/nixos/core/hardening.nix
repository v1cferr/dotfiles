# The sandbox baseline for this repo's own ROOT oneshots, as one read-only option (rule 11). Which
# units take it, the scores before and after, and the ones left out: docs/notes/repo/hardening.md
{ lib, ... }:

{
  options.my.systemd.hardened = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    readOnly = true;
    description = "systemd serviceConfig for a root oneshot that only touches files and Unix sockets.";
    default = {
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateNetwork = true; # every taker talks over Unix sockets only (docker, D-Bus) or not at all
      RestrictAddressFamilies = [ "AF_UNIX" ];
      ProtectSystem = "full";
      ProtectHome = "read-only"; # not `true`: the docker CLI reads /root/.docker
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };
}
