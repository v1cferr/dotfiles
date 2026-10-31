# COCKPIT: start/stop any systemd unit from the browser (ops.<domain>), the compose stacks
# included through their units. Why Cockpit and the proxy settings: docs/notes/services/cockpit.md
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    cockpit-files
    cockpit-machines
    ;
in
lib.mkIf config.my.services.cockpit {
  services.cockpit = {
    enable = true;
    showBanner = false; # no "Web console: ..." line in every motd/issue
    # The libvirt guests (start/stop plus their console) and a file browser; why these two only: the note.
    plugins = [
      cockpit-machines
      cockpit-files
    ];
    allowed-origins = [ "https://ops.${config.my.net.domain}" ];
    # Caddy terminates TLS and talks plain HTTP to it; trust its headers for scheme and client IP.
    settings.WebService = {
      AllowUnencrypted = true;
      ProtocolHeader = "X-Forwarded-Proto";
      ForwardedForHeader = "X-Forwarded-For";
    };
  };

  # Kernel dump only checks that kexec exists, and kdump is not set up here: a JSON merge patch
  # drops its menu entry. packagekit, selinux and sosreport already hide themselves.
  environment.etc."cockpit/kdump.override.json".text = builtins.toJSON { tools = null; };

  # Loopback only: Caddy is the single way in. The "" resets the unit's own ListenStream.
  systemd.sockets.cockpit.listenStreams = lib.mkForce [
    ""
    "127.0.0.1:${toString config.services.cockpit.port}"
  ];
}
