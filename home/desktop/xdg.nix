# ═══════════════════════════════════════════════════════════════════════════
# XDG — browser default (Zen) + menu de aplicativos p/ os apps KDE.
#
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
  code = "code.desktop"; # VS Code (instalado em home/packages.nix)
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

      # ── Texto/código → VS Code ──
      # Sem isto o duplo-clique caía no Okular (que reivindica text/plain e markdown
      # no .desktop dele) ou em NADA (json/csv/yaml/toml/py/js não tinham handler).
      "text/plain" = code; # tb. cobre .nix/.ini/.conf/.env
      "text/markdown" = code;
      "text/x-log" = code;
      "text/csv" = code;
      "application/json" = code;
      "application/yaml" = code;
      "application/toml" = code;
      "text/x-python" = code;
      "text/javascript" = code;
      "text/vnd.trolltech.linguist" = code; # .ts: o shared-mime-info casa Qt Linguist, não TypeScript
    };
  };

  # ── applications.menu — sem ele, apps KDE não abrem NADA no duplo-clique ──
  #
  # Apps KF6 (Dolphin/Gwenview/Okular/Ark) resolvem "quem abre este arquivo" pelo
  # KApplicationTrader, que lê o índice ksycoca. E o kbuildsycoca só descobre os
  # .desktop percorrendo o menu XDG (`applications.menu`) — sem esse arquivo ele
  # indexa ZERO aplicativos e o duplo-clique falha em silêncio, mesmo com o
  # mimeapps.list certinho ("applications.menu not found in …" no journal).
  #
  # O Plasma traria o dele (plasma-applications.menu), mas aqui a sessão é
  # Hyprland → precisa ser declarado. Menu chapado (<All/>) porque o único
  # consumidor é o índice do ksycoca, não um lançador com categorias — o rofi
  # lê os .desktop direto. Se algum dia o Plasma entrar, ele usa o prefixo
  # XDG_MENU_PREFIX=plasma- e ignora este arquivo (sem conflito).
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

  # Apps de terminal (git, gh, xdg-open…) leem $BROWSER, não o mimeapps.
  home.sessionVariables.BROWSER = "zen-beta";
}
