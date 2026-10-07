# The band's SERVICES carousel: what to watch, from the host's toggles and ingress, plus the
# `dash-services-meta` that resolves it live. Why a catalog: docs/notes/desktop/dash.md
{
  pkgs,
  lib,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    docker-client
    jq
    systemd
    writeShellApplication
    ;

  on = name: osConfig.my.services.${name} or false;
  ingress = osConfig.my.ingress;
  # A tunnel-only name sits behind Access with no browser login, so it is no place to click to.
  urlOf =
    name:
    if name != null && ingress ? ${name} && ingress.${name}.expose != "tunnel" then
      "https://${name}.${osConfig.my.net.domain}"
    else
      null;

  # toggle -> what it is on this machine. `system`/`user` are systemd units, summed into one card;
  # `compose` is a Docker compose project (its containers are found live by label); `ingress` names
  # the subdomain a click opens. Compose projects NOT listed here still show up, discovered live.
  catalog = {
    jellyfin = {
      label = "jellyfin";
      system = [ "jellyfin.service" ];
      ingress = "jellyfin";
    };
    immich = {
      label = "immich";
      system = [
        "immich-server.service"
        "immich-machine-learning.service"
        "redis-immich.service"
        "postgresql.service" # immich's alone on this host (immich.nix)
      ];
      ingress = "photos";
    };
    ollama = {
      label = "ollama";
      system = [ "ollama.service" ];
      ingress = "ai";
    };
    qbittorrent = {
      label = "qbittorrent";
      system = [ "qbittorrent.service" ];
      ingress = "torrent";
    };
    caddy = {
      label = "caddy";
      system = [ "caddy.service" ];
    };
    tunnel = {
      label = "cloudflared";
      system = lib.optional (
        osConfig.my.net.tunnel.id != null
      ) "cloudflared-tunnel-${osConfig.my.net.tunnel.id}.service";
    };
    ci-webhook = {
      label = "ci-webhook";
      system = [ "webhook.service" ];
    };
    tor = {
      label = "tor";
      system = [ "tor.service" ];
    };
    libvirt = {
      label = "libvirt";
      system = [ "libvirtd.service" ];
    };
    sunshine = {
      label = "sunshine";
      user = [ "sunshine.service" ];
    };
    basic-memory = {
      label = "basic-memory";
      user = [
        "basic-memory-general.service"
        "basic-memory-fai.service"
      ];
    };
    dropbox = {
      label = "dropbox";
      user = [ "dropbox.service" ];
    };
    drive-mount = {
      label = "drive";
      user = [ "drive-mount.service" ];
    };
    arch-antigo-mount = {
      label = "arch-antigo";
      user = [ "arch-antigo-mount.service" ];
    };
    duo = {
      label = "duo";
      compose = "duo";
      ingress = "duo";
    };
    grad-radar = {
      label = "grad-radar";
      compose = "grad-radar";
      ingress = "pos";
    };
    credit-radar = {
      label = "credit-radar";
      compose = "credit-radar";
      ingress = "credit";
    };
  };

  enabled = lib.filterAttrs (name: _: on name) catalog;

  meta = writeShellApplication {
    name = "dash-services-meta";
    runtimeInputs = [
      systemd
      docker-client
      jq
      coreutils
    ];
    text = builtins.readFile ./scripts/services-meta.sh;
  };
in
{
  home.packages = [ meta ];

  # Data for Quickshell, the same path and the same reason as weather.json and the palette.
  home.file.".config/theme/dash-services.json".text = builtins.toJSON (
    lib.mapAttrsToList (key: s: {
      inherit key;
      inherit (s) label;
      system = s.system or [ ];
      user = s.user or [ ];
      compose = s.compose or null;
      url = urlOf (s.ingress or null);
    }) enabled
  );
}
