# SECRETS: Bitwarden is the source of truth, sops-nix is the vault, the repo holds none (rule 12).
# The index, the two recipients and who can read what: docs/notes/repo/secrets.md
{ pkgs, lib, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    bitwarden-cli
    git
    jq
    sops
    writeShellApplication
    ;

  # The public index: { "<name-in-sops>" = "<item-in-Bitwarden>"; ... }
  bwMap = builtins.fromJSON (builtins.readFile ../../secrets/bitwarden-secrets.json);

  # The keys secrets.yaml ACTUALLY holds. sops encrypts the values and leaves the
  # keys in plain text, so this is readable at eval time, with no age key and no
  # --impure.
  sopsKeys =
    let
      lines = lib.splitString "\n" (builtins.readFile ../../secrets/secrets.yaml);
      declared = builtins.filter (line: builtins.match "[A-Za-z0-9_]+:.*" line != null) lines;
    in
    # "sops" is sops' own metadata block, not a secret.
    lib.subtractLists [ "sops" ] (map (line: builtins.head (lib.splitString ":" line)) declared);

  # The index, minus whatever has not been synced yet. This is what takes the ORDER
  # out of it: a declared secret missing from secrets.yaml passes the BUILD and
  # breaks the ACTIVATION, so adding a line here and rebuilding before running
  # `sync-secrets` used to bring the whole switch down over one line of JSON. A new
  # entry now stays inert until it actually exists.
  syncedMap = lib.filterAttrs (key: _item: builtins.elem key sopsKeys) bwMap;

  sync-secrets = writeShellApplication {
    name = "sync-secrets";
    runtimeInputs = [
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
    (lib.mapAttrs (_key: _item: { }) syncedMap)
    // {
      v1cferr_password_hash.neededForUsers = true; # the password hash: it is needed early (the user)
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
    # Conditional on the VAULT, not on the index: an owner and a mode only mean
    # something once the secret exists, and secrets.yaml is what decides that.
    // lib.optionalAttrs (builtins.elem "ntfy_topic" sopsKeys) {
      ntfy_topic = {
        owner = "v1cferr";
        mode = "0400";
      };
    }
    // lib.optionalAttrs (builtins.elem "stitch_api_key" sopsKeys) {
      stitch_api_key = {
        owner = "v1cferr";
        mode = "0400";
      }; # user-readable: the `claude` launcher reads it to reach the Stitch MCP
    };

  environment.systemPackages = [ sync-secrets ];
}
