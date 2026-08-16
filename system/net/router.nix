# `router-sync`: mirrors the OpenWrt UCI into the repo, with secrets redacted. It does NOT push.
# Pushing needs commit-confirm; the open decision is in docs/open-items.md.
{ pkgs, ... }:

let
  # Python and not shell: the redaction is fail-safe per option, which sed would get wrong.
  routerSyncPy = pkgs.writeText "router-sync.py" (builtins.readFile ../../scripts/router-sync.py);
in
{
  # The logic lives in the build (rule 7); openssh is explicit so it never uses the user's PATH.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "router-sync";
      runtimeInputs = with pkgs; [
        python3
        openssh
        git # it finds the repo's root (the same idiom as scripts/sync-secrets.sh)
      ];
      text = ''exec python3 ${routerSyncPy} "$@"'';
    })
  ];
}
