# THE KEYRING UNLOCK: the "Login" password sealed in the TPM (PCR7), fed to the daemon at start,
# because autologin never types one. Why and what was rejected: docs/notes/desktop/desktop.md
{
  config,
  pkgs,
  osConfig,
  ...
}:

let
  inherit (pkgs) systemd writeShellApplication;

  credName = "keyring-login"; # embedded in the blob, so a renamed file cannot be swapped in
  credFile = "${config.xdg.stateHome}/keyring/login.cred"; # STATE (rule 6): useless off this TPM
  daemon = "${osConfig.security.wrapperDir}/gnome-keyring-daemon"; # the wrapper carries cap_ipc_lock

  # Starts the daemon unlocked; with no blob or a changed PCR7 it starts LOCKED and the usual
  # prompt takes over, so a TPM failure costs one password, never the secrets.
  start = writeShellApplication {
    name = "keyring-tpm-start";
    runtimeInputs = [ systemd ];
    text = ''
      if [ -r ${credFile} ] && pw="$(systemd-creds decrypt --user --name=${credName} ${credFile} -)"; then
        exec ${daemon} --foreground --components=secrets --unlock < <(printf '%s' "$pw")
      fi
      echo "<4>no usable TPM credential at ${credFile}, starting the keyring locked"
      exec ${daemon} --foreground --components=secrets
    '';
  };

  # Run by hand after changing the keyring password in Seahorse, and after a PCR7 change.
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
      echo "sealed to ${credFile}"
    '';
  };

  # Every name the daemon owns is redirected to the unit, so whoever activates it FIRST gets an
  # unlocked one and there is no race. $XDG_DATA_HOME wins over the system copies.
  busNames = [
    "org.freedesktop.secrets"
    "org.gnome.keyring"
    "org.freedesktop.impl.portal.Secret"
  ];
  activation = name: {
    name = "dbus-1/services/${name}.service";
    value.text = ''
      [D-BUS Service]
      Name=${name}
      Exec=${start}/bin/keyring-tpm-start
      SystemdService=gnome-keyring-tpm.service
    '';
  };
in
{
  home.packages = [ seal ];

  xdg.dataFile = builtins.listToAttrs (map activation busNames);

  systemd.user.services.gnome-keyring-tpm = {
    Unit.Description = "gnome-keyring, unlocked from a TPM-sealed password";
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.secrets";
      ExecStart = "${start}/bin/keyring-tpm-start";
      Restart = "on-failure";
    };
    # NO Install: D-Bus activation is the one starter (rule 15).
  };
}
