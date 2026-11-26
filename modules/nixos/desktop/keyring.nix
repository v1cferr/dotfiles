# THE SECRET SERVICE: oo7 (gnome-keyring's successor) plus gcr's SSH agent and prompter. It mirrors
# unstable's services.oo7 minus PAM, swap at 26.11. Why and how it unlocks: docs/notes/desktop/desktop.md
{ pkgs, config, ... }:

let
  inherit (pkgs) gcr glib writeTextDir;
  inherit (pkgs.unstable) oo7 oo7-server;

  daemon = "${config.security.wrapperDir}/oo7-daemon";

  # D-Bus activation is the one starter (rule 15): whoever asks for a secret first starts the unit.
  activation = writeTextDir "share/dbus-1/services/org.freedesktop.secrets.service" ''
    [D-BUS Service]
    Name=org.freedesktop.secrets
    Exec=${daemon}
    SystemdService=oo7-daemon.service
  '';
in
{
  # 26.05 only collects lib/systemd/user, and oo7 ships share/systemd/user: its unit, verbatim.
  systemd.user.services.oo7-daemon = {
    description = "Secret service (oo7 implementation)";
    serviceConfig = {
      Type = "dbus";
      BusName = "org.freedesktop.secrets";
      ExecStart = daemon;
      Restart = "on-failure";
      TimeoutStartSec = "30s";
      TimeoutStopSec = "30s";
      # The login keyring's password, TPM-sealed in ~/.config/credstore.encrypted (keyring-tpm-seal).
      ImportCredential = "oo7.keyring-encryption-password";
      NoNewPrivileges = true;
      SupplementaryGroups = "";
      PrivateUsers = true;
      ProtectSystem = "full";
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateNetwork = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      MemoryDenyWriteExecute = true;
      ProtectClock = true;
    };
  };

  security.wrappers.oo7-daemon = {
    owner = "root";
    group = "root";
    capabilities = "cap_ipc_lock=ep"; # mlock, so secrets never reach swap
    source = "${oo7-server}/libexec/oo7-daemon";
  };

  # gcr's prompter (org.gnome.keyring.SystemPrompter) is the dialog oo7 opens when it needs a password.
  services.dbus.packages = [
    activation
    gcr
  ];

  # gcr 4's SSH agent, which keeps key passphrases in whichever Secret Service runs.
  services.gnome.gcr-ssh-agent.enable = true;

  # Electron finds the keyring only through this var: Chromium matches no "Hyprland" and falls back to it.
  environment.sessionVariables.GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";

  environment.systemPackages = [
    oo7 # oo7-cli: list, lookup, and change-secret for the keyring's password
    glib # gio: that var makes xdg-open take its GNOME branch, which opens files through gio
  ];
}
