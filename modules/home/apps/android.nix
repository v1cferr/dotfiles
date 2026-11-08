# Android over ADB: the read-only posture audit, plus measuring storage and trimming caches.
# Pairing, the commands and why SFTP could not do this job: docs/notes/hardware/android.md
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    android-iac
    android-tools
    git
    jq
    scrcpy
    sops
    universal-android-debloater
    writeShellApplication
    ;

  # The phone's apps, sealed in sops so they are versioned and private (docs/notes/hardware/android-iac.md).
  sealed = osConfig.sops.secrets.android_iac_local or null;
  android-iac-seal = writeShellApplication {
    name = "android-iac-seal";
    runtimeInputs = [
      android-iac
      git
      jq
      sops
    ];
    text = builtins.readFile ../../../tools/android-iac/scripts/android-iac-seal.sh;
  };
in
{
  # User apps with no root need, hence home (rule 4): no `programs.adb` and no adbusers group,
  # since systemd grants USB access through uaccess and wireless debugging dials OUT to the phone.
  home.packages = [
    android-iac # the phone's posture against hosts/motorola-edge-70-fusion, read-only
    android-iac-seal # pulls the phone's apps and seals them into secrets/secrets.yaml
    android-tools # adb and fastboot
    scrcpy # the phone's screen mirrored and driven from here
    universal-android-debloater # uad-ng: a GUI over adb with a safety rating per package
  ];

  # The overlay android-iac reads, straight from /run/secrets: readable here, no sudo, to audit.
  xdg.configFile."android-iac/local.json" = lib.mkIf (sealed != null) {
    source = config.lib.file.mkOutOfStoreSymlink sealed.path;
  };
}
