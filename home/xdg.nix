# ═══════════════════════════════════════════════════════════════════════════
# BROWSER DEFAULT (declarativo) — Zen Browser.
#
# Segue a regra do home/: aqui NÃO se instala (o pacote Zen vem do flake, em
# system/default.nix). Aqui só se ASSOCIA — qual .desktop abre link http/https.
#
# xdg.mimeApps escreve ~/.config/mimeapps.org (gerenciado, read-only) e é o que
# `xdg-settings get default-web-browser` e os apps GTK/Electron consultam. O
# .desktop do Zen é `zen-beta.desktop` (Exec=zen-beta; declara os schemes http/
# https/html/xml) — confira com `xdg-mime query default x-scheme-handler/https`.
#
# BROWSER na sessão fecha o caso dos apps de terminal (git, gh, xdg-open CLI…)
# que ignoram o mimeapps e leem a env var.
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

let
  zen = "zen-beta.desktop";
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = zen;
      "x-scheme-handler/https" = zen;
      "x-scheme-handler/about" = zen; # about:blank etc.
      "x-scheme-handler/unknown" = zen; # fallback de scheme desconhecido
      "text/html" = zen;
      "application/xhtml+xml" = zen;
    };
  };

  # Apps de terminal (git, gh, xdg-open…) leem $BROWSER, não o mimeapps.
  home.sessionVariables.BROWSER = "zen-beta";
}
