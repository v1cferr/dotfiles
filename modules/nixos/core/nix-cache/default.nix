# THE OWN BINARY CACHE: what CI builds every night, read back from a private R2 bucket.
# Why a private bucket, the read-only key and what gets pushed: docs/notes/repo/nix-cache.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    bitwarden-cli
    gh
    jq
    writeShellApplication
    ;

  # Shared with .github/workflows/cache.yml, so the bucket and the endpoint are written once.
  cache = lib.importJSON ./cache.json;
  pubKeyFile = ./nix-cache.pub; # written by nix-cache-setup; public by definition

  # Inert until BOTH halves exist: the public key in git and the read-only key in sops.
  enabled = builtins.pathExists pubKeyFile && config.sops.secrets ? nix_cache_r2_read_secret;

  # The one-time setup: signing key plus the R2 tokens into GitHub and Bitwarden, never on screen.
  nix-cache-setup = writeShellApplication {
    name = "nix-cache-setup";
    runtimeInputs = [
      bitwarden-cli
      gh
      jq
    ];
    text = builtins.readFile ./scripts/setup.sh; # bash in its own file = shellcheck at build time
  };
in
{
  environment.systemPackages = [ nix-cache-setup ];

  # After cache.nixos.org (priority 40), so the official cache still answers what it has.
  nix.settings.extra-substituters = lib.mkIf enabled [
    "s3://${cache.bucket}?endpoint=${cache.endpoint}&region=auto&priority=45"
  ];
  nix.settings.extra-trusted-public-keys = lib.mkIf enabled [
    (lib.removeSuffix "\n" (builtins.readFile pubKeyFile))
  ];

  # The daemon is what fetches, so the read-only key goes into ITS environment, never the store.
  sops.templates."nix-cache-r2.env" = lib.mkIf enabled {
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.nix_cache_r2_read_key_id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.nix_cache_r2_read_secret}
    '';
  };
  systemd.services.nix-daemon.serviceConfig.EnvironmentFile = lib.mkIf enabled [
    config.sops.templates."nix-cache-r2.env".path
  ];
}
