# XDG: the default browser (Zen) plus the file associations. Nothing is INSTALLED here (rule 4).
# Why applications.menu is mandatory for the KDE apps: docs/notes/desktop-plumbing.md
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

      # Text/code to VS Code: without this a double click fell into Okular or into NOTHING.
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

  # applications.menu: KF6 resolves handlers through ksycoca, and kbuildsycoca only finds the
  # .desktop files by walking THIS menu. Without it, a double click fails in silence.
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

  # Terminal apps (git, gh, xdg-open) read $BROWSER, not mimeapps.
  home.sessionVariables.BROWSER = "zen-beta";
}
