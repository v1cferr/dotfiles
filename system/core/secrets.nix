# ═══════════════════════════════════════════════════════════════════════════
# AUTOMATIC SECRETS: Bitwarden as the source of truth, sops as the vault.
#
# The PUBLIC index secrets/bitwarden-secrets.json maps name-in-sops -> item-in-Bitwarden (it is
# not a secret; it goes into git). From it:
#   1. nix GENERATES the `sops.secrets.<name>` on its own (never declare one by hand again);
#   2. the `sync-secrets` command pulls the values from Bitwarden and writes them ENCRYPTED into
#      secrets.yaml (through sops set), so the rebuild stays PURE (no --impure).
#
# Adding a secret: register it in Bitwarden -> 1 more line in the JSON -> `sync-secrets`
# -> `nixos-rebuild switch`. Secrets that do NOT come from Bitwarden (the user's password hash,
# for instance) stay declared by hand in default.nix.
# ═══════════════════════════════════════════════════════════════════════════
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
  # ── The sops-nix base ──────────────────────────────────────────────────────
  # secrets/secrets.yaml: encrypted, versioned, unreadable without the key. Decrypted at runtime
  # into /run/secrets*. The age key (/var/lib/sops-nix/key.txt) stays OUT of git; it is what you
  # carry across a cutover. To edit: nix shell nixpkgs#sops -c sops secrets/secrets.yaml
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";

  # It generates a sops.secrets.<name> = {} for every entry in the index (Bitwarden), and merges
  # (//) the secrets that do NOT come from Bitwarden (declared by hand).
  sops.secrets =
    (lib.mapAttrs (_key: _item: { }) bwMap)
    // {
      v1cferr_password_hash.neededForUsers = true; # the password hash: it is needed early (the user)
      cloudflare_ddns_token = { };
      jellyfin_api_key = {
        owner = "v1cferr";
        mode = "0400";
      }; # readable for the user's tooling in /run/secrets (with no sudo)
      deepl_api_key = {
        owner = "v1cferr";
        mode = "0400";
      }; # translating the lockscreen's quotes (a --user service reads /run/secrets)
      # The ntfy topic: the `notify` command (home/shell/ntfy.nix) runs as the user, and so do the
      # --user timers that warn. The same pattern as deepl above.
      #
      # Conditional on the index on purpose: declaring a sops.secrets whose key is not in
      # secrets.yaml yet passes the BUILD and breaks at ACTIVATION ("secret does not exist"),
      # which is to say it takes the switch down. This way the module stays inert until
      # `sync-secrets` has run, which is the same rule the rest of this file follows.
      # The Google Drive rclone.conf (an OAuth token). OUT of Bitwarden on purpose: it is
      # MULTILINE and sync-secrets does a `sops set` with single-line JSON, which would break it.
      # And, unlike the restic password, the token is REGENERABLE (redo the OAuth), so it does not
      # need the vault. To edit: nix shell nixpkgs#sops -c sops secrets/secrets.yaml
      # owner v1cferr: the ~/Drive mount is a --user service (home/services/drive-mount.nix) and
      # it needs to READ this without sudo. restic keeps reading it, since it runs as root, which
      # reads somebody else's 0400. The same pattern as jellyfin_api_key/deepl_api_key above.
      rclone_gdrive_conf = {
        owner = "v1cferr";
        mode = "0400";
      };
      # THE RESTIC REPO PASSWORDS readable by the user. The reason: a `restic mount` is only
      # browsable by WHOEVER MOUNTED IT, since a FUSE mount is private by default, which this very
      # config has already proven inside out (restic as ROOT could not even lstat the USER's FUSE
      # mount at ~/FAI-workstation). Mounting with sudo gave a folder Dolphin does not open;
      # mounting as the user requires reading the password without sudo.
      # It is not privilege escalation: it is the backup password for THIS SAME USER'S DATA, and
      # whoever already is v1cferr has the original files. The same pattern as jellyfin/deepl.
      restic_password = {
        owner = "v1cferr";
        mode = "0400";
      };
      restic_password_arch_kingston = {
        owner = "v1cferr";
        mode = "0400";
      };
    }
    # Conditional on the index on purpose: declaring a sops.secrets whose key is not in
    # secrets.yaml yet passes the BUILD and breaks at ACTIVATION ("secret does not exist"), taking
    # the switch down. This way it stays inert until `sync-secrets` has run, the same rule as the
    # rest of this file.
    # The `notify` command (home/shell/ntfy.nix) runs as the user, and so do the --user timers
    # that warn: owner v1cferr, just like deepl above.
    // lib.optionalAttrs (bwMap ? ntfy_topic) {
      ntfy_topic = {
        owner = "v1cferr";
        mode = "0400";
      };
    };

  environment.systemPackages = [ sync-secrets ];
}
