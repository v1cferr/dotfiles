# `router-sync`: mirrors the OpenWrt UCI into the repo, with secrets redacted. It does NOT push.
# Pushing needs commit-confirm; the open decision is in docs/open-items.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    git
    openssh
    python3
    writeShellApplication
    writeText
    ;

  # Python and not shell: the redaction is fail-safe per option, which sed would get wrong.
  routerSyncPy = writeText "router-sync.py" (builtins.readFile ./router-sync.py);

  cfg = config.my.router;
  inherit (lib) mkOption types;
in
{
  # The router this machine manages. NO default: the host wires the router's own data file.
  options.my.router = {
    address = mkOption {
      type = types.str;
      description = "The router's LAN address: the gateway, and where router-sync and `ssh router` connect.";
    };
    sshUser = mkOption {
      type = types.str;
      description = "The account router-sync logs into (it reads with `sudo uci show`).";
    };
    mirror = mkOption {
      type = types.str;
      description = "The UCI mirror's folder, relative to the repo root: router-sync writes it there.";
    };
  };

  # The logic lives in the build (rule 7); openssh is explicit so it never uses the user's PATH.
  config.environment.systemPackages = [
    (writeShellApplication {
      name = "router-sync";
      runtimeInputs = [
        python3
        openssh
        git # it finds the repo's root (the same idiom as modules/nixos/core/sync-secrets.sh)
      ];
      text = ''
        export ROUTER_HOST=${lib.escapeShellArg "${cfg.sshUser}@${cfg.address}"}
        export ROUTER_MIRROR=${lib.escapeShellArg cfg.mirror}
        exec python3 ${routerSyncPy} "$@"
      '';
    })
  ];
}
