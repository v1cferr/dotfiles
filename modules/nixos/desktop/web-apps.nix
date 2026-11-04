# WEB APPS: sites Chrome installs as apps in the profile already signed in, through its managed
# policy. Gemini has no Linux app (Windows and macOS only); why not a wrapper: docs/notes/apps/gemini.md
{ ... }:

{
  # Merged with the spellcheck keys into the same /etc/opt/chrome/policies JSON. An installed app
  # gets its own Wayland app_id (chrome-<id>-Default), which a plain `--app=` window does not.
  programs.chromium.extraOpts.WebAppInstallForceList = [
    {
      url = "https://gemini.google.com/app";
      default_launch_container = "window";
      create_desktop_shortcut = false; # the launcher entry is enough; nothing on a desktop
    }
  ];
}
