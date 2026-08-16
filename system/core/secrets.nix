# SECRETS: Bitwarden is the source of truth, sops-nix is the vault, the repo holds none (rule 12).
# The index, the two recipients and who can read what: docs/notes/secrets.md
{ pkgs, lib, ... }:

let
  # The public index: { "<name-in-sops>" = "<item-in-Bitwarden>"; ... }
  bwMap = builtins.fromJSON (builtins.readFile ../../secrets/bitwarden-secrets.json);

  sync-secrets = pkgs.writeShellApplication {
    name = "sync-secrets";
    runtimeInputs = with pkgs; [
      bitwarden-cli
      jq
      sops
      git
    ];
    text = builtins.readFile ../../scripts/sync-secrets.sh; # bash in its own file = shellcheck at build time
  };
in
{
  # The age key (/var/lib/sops-nix/key.txt) stays OUT of git: it is what you carry on a cutover.
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # One sops.secrets.<name> per index entry, merged with the hand-declared ones.
  sops.secrets =
    (lib.mapAttrs (_key: _item: { }) bwMap)
    // {
      v1cferr_password_hash.neededForUsers = true; # the password hash: it is needed early (the user)
      cloudflare_ddns_token = { };
      jellyfin_api_key = {
        owner = "v1cferr";
        mode = "0400";
      }; # user-readable: consumed by user tooling
      deepl_api_key = {
        owner = "v1cferr";
        mode = "0400";
      }; # user-readable: the lockscreen quote fetcher is a --user service
      # OUT of Bitwarden: it is MULTILINE and `sops set` writes single-line JSON.
      rclone_gdrive_conf = {
        owner = "v1cferr";
        mode = "0400";
      };
      # User-readable because a FUSE mount is private to whoever mounted it: `sudo restic mount`
      # produces a folder Dolphin cannot open.
      restic_password = {
        owner = "v1cferr";
        mode = "0400";
      };
      restic_password_arch_kingston = {
        owner = "v1cferr";
        mode = "0400";
      };
    }
    # Conditional on the index: a declared secret missing from secrets.yaml passes the BUILD and
    # breaks the ACTIVATION, so this stays inert until `sync-secrets` has run.
    // lib.optionalAttrs (bwMap ? ntfy_topic) {
      ntfy_topic = {
        owner = "v1cferr";
        mode = "0400";
      };
    };

  environment.systemPackages = [ sync-secrets ];
}
