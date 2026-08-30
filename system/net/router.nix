# `router-sync`: mirrors the OpenWrt UCI into the repo, with secrets redacted. It does NOT push.
# Pushing needs commit-confirm; the open decision is in docs/open-items.md.
{ pkgs, ... }:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    git
    openssh
    python3
    writeShellApplication
    writeText
    ;

  # Python and not shell: the redaction is fail-safe per option, which sed would get wrong.
  routerSyncPy = writeText "router-sync.py" (builtins.readFile ../../scripts/router-sync.py);
in
{
  # The logic lives in the build (rule 7); openssh is explicit so it never uses the user's PATH.
  environment.systemPackages = [
    (writeShellApplication {
      name = "router-sync";
      runtimeInputs = [
        python3
        openssh
        git # it finds the repo's root (the same idiom as scripts/sync-secrets.sh)
      ];
      text = ''exec python3 ${routerSyncPy} "$@"'';
    })
  ];
}
