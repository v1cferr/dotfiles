# XDG: the default browser (Zen) plus the application menu for the KDE apps.
#
# THE DEFAULT BROWSER (declarative): Zen Browser.
#
# It follows the home/ rule: nothing is INSTALLED here (the Zen package comes from the flake, in
# system/default.nix). Here we only ASSOCIATE, meaning which .desktop opens an http/https link.
#
# xdg.mimeApps writes ~/.config/mimeapps.list (managed, read-only) and it is what
# `xdg-settings get default-web-browser` and the GTK/Electron apps consult. Zen's .desktop is
# `zen-beta.desktop` (Exec=zen-beta; it declares the http/https/html/xml schemes); check it with
# `xdg-mime query default x-scheme-handler/https`.
#
# BROWSER in the session closes the case of the terminal apps (git, gh, the xdg-open CLI and so
# on) that ignore mimeapps and read the env var.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

let
  zen = "zen-beta.desktop";
  code = "code.desktop"; # VS Code (installed in home/packages.nix)
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = zen;
      "x-scheme-handler/https" = zen;
      "x-scheme-handler/about" = zen; # about:blank and so on
      "x-scheme-handler/unknown" = zen; # the fallback for an unknown scheme
      "text/html" = zen;
      "application/xhtml+xml" = zen;

      # ── Text/code -> VS Code ──
      # Without this a double click fell into Okular (which claims text/plain and markdown in its
      # .desktop) or into NOTHING (json/csv/yaml/toml/py/js had no handler).
      "text/plain" = code; # it also covers .nix/.ini/.conf/.env
      "text/markdown" = code;
      "text/x-log" = code;
      "text/csv" = code;
      "application/json" = code;
      "application/yaml" = code;
      "application/toml" = code;
      "text/x-python" = code;
      "text/javascript" = code;
      "text/vnd.trolltech.linguist" = code; # .ts: shared-mime-info matches Qt Linguist, not TypeScript
    };
  };

  # ── applications.menu: without it, KDE apps open NOTHING on a double click ──
  #
  # KF6 apps (Dolphin/Gwenview/Okular/Ark) resolve "who opens this file" through
  # KApplicationTrader, which reads the ksycoca index. And kbuildsycoca only discovers the
  # .desktop files by walking the XDG menu (`applications.menu`), so without that file it indexes
  # ZERO applications and the double click fails in silence, even with a perfectly fine
  # mimeapps.list ("applications.menu not found in …" in the journal).
  #
  # Plasma would bring its own (plasma-applications.menu), but here the session is Hyprland, so it
  # has to be declared. A flat menu (<All/>) because the only consumer is the ksycoca index, not a
  # launcher with categories: rofi reads the .desktop files directly. If Plasma ever comes in, it
  # uses the XDG_MENU_PREFIX=plasma- prefix and ignores this file (no conflict).
  xdg.configFile."menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Include><All/></Include>
    </Menu>
  '';

  # Terminal apps (git, gh, xdg-open…) read $BROWSER, not mimeapps.
  home.sessionVariables.BROWSER = "zen-beta";
}
