# THE KEYRING UNLOCK: the "Login" password TPM-sealed (PCR7) as the credential oo7-daemon imports at
# start, because autologin never types one. Why and what was rejected: docs/notes/desktop/desktop.md
{ config, pkgs, ... }:

let
  inherit (pkgs) systemd writeShellApplication;

  # The name oo7's unit imports (ImportCredential), embedded in the blob so no other file can stand in.
  credName = "oo7.keyring-encryption-password";
  # The user credstore that `ImportCredential` searches. STATE (rule 6): useless off this TPM.
  credFile = "${config.xdg.configHome}/credstore.encrypted/${credName}";

  # Run by hand after `oo7-cli change-secret`, and after a PCR7 change (the daemon then starts locked
  # and gcr's prompt asks once, so a TPM failure costs one password, never the secrets).
  seal = writeShellApplication {
    name = "keyring-tpm-seal";
    runtimeInputs = [ systemd ];
    text = ''
      pw="$(systemd-ask-password --timeout=0 'Login keyring password:')"
      again="$(systemd-ask-password --timeout=0 'Again:')"
      [ "$pw" = "$again" ] || { echo "the passwords differ, nothing sealed" >&2; exit 1; }
      [ -n "$pw" ] || { echo "an empty password needs no TPM, nothing sealed" >&2; exit 1; }
      umask 077 # the blob only opens on this TPM, but it is still nobody else's business
      mkdir -p "$(dirname ${credFile})"
      printf '%s' "$pw" | systemd-creds encrypt --user --with-key=host+tpm2 --tpm2-pcrs=7 \
        --name=${credName} - ${credFile}
      echo "sealed to ${credFile}; restart oo7-daemon (or log in again) to use it"
    '';
  };
in
{
  home.packages = [ seal ];
}
