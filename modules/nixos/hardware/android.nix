# Android over ADB: wireless debugging to measure storage, trim caches and remove bloat.
# Pairing, the commands and why SFTP could not do this job: docs/notes/hardware/android.md
{ pkgs, ... }:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    android-tools
    scrcpy
    universal-android-debloater
    ;
in
{
  # No `programs.adb` and no adbusers group: systemd 258 grants USB access through uaccess, and
  # wireless debugging dials OUT to the phone, so the firewall needs no port either.
  environment.systemPackages = [
    android-tools # adb and fastboot
    scrcpy # the phone's screen mirrored and driven from here
    universal-android-debloater # uad-ng: a GUI over adb with a safety rating per package
  ];
}
