# ═══════════════════════════════════════════════════════════════════════════
# MÍDIA (nível-usuário) — visualizadores, players e apps PADRÃO por tipo.
#
# Regra do home/ (ver home/default.nix): app de USUÁRIO fica aqui. Escolha do
# stack: KDE Gear (Gwenview/Okular) porque este sistema já é Qt/Kvantum + Dolphin
# → entra tematizado de graça e integra com o file manager (abrir-com, miniaturas).
# kimageformats + qtimageformats dão os formatos modernos (AVIF/HEIF/JXL/WebP/RAW).
#
# As associações xdg.mimeApps abaixo se FUNDEM com as do home/xdg.nix (browser) —
# home-manager mescla os defaultApplications de todos os módulos num só mimeapps.list.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # .desktop dos apps (usados só nas associações de tipo abaixo; não colidem c/ pkgs)
  app = {
    gwenview = "org.kde.gwenview.desktop";
    okular = "org.kde.okular.desktop";
    vlc = "vlc.desktop";
  };
in
{
  home.packages = with pkgs; [
    kdePackages.gwenview # visualizador de imagens (KDE): edição básica + miniaturas
    kdePackages.okular # leitor de documentos (KDE): PDF/EPUB/CBZ + anotações
    kdePackages.kimageformats # plugins de formato p/ apps KDE: AVIF/HEIF/JXL/PSD/RAW
    kdePackages.qtimageformats # plugins Qt: WebP/TIFF/ICNS (complementa o kimageformats)
    vlc # player de vídeo GUI faz-tudo (é o default de vídeo, mais abaixo)
  ];

  # mpv: player leve/scriptável, companheiro do VLC. Módulo programs.* = idiomático.
  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe"; # decodifica por GPU quando seguro (poupa CPU)
      vo = "gpu-next"; # saída de vídeo moderna (melhor HDR/tone-mapping no Wayland)
    };
  };

  # Apps padrão por tipo de arquivo (declarativo). Funde com o home/xdg.nix.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # ── Imagens → Gwenview ──
      "image/png" = app.gwenview;
      "image/jpeg" = app.gwenview;
      "image/gif" = app.gwenview;
      "image/webp" = app.gwenview;
      "image/bmp" = app.gwenview;
      "image/tiff" = app.gwenview;
      "image/svg+xml" = app.gwenview;
      "image/avif" = app.gwenview;
      "image/heif" = app.gwenview;
      "image/heic" = app.gwenview;
      "image/jxl" = app.gwenview;
      # ── Documentos → Okular ──
      "application/pdf" = app.okular;
      "application/epub+zip" = app.okular;
      "application/vnd.comicbook+zip" = app.okular; # .cbz
      # ── Vídeo → VLC (mpv fica p/ abrir manual/CLI) ──
      "video/mp4" = app.vlc;
      "video/x-matroska" = app.vlc; # .mkv
      "video/webm" = app.vlc;
      "video/quicktime" = app.vlc; # .mov
      "video/x-msvideo" = app.vlc; # .avi
      "video/mpeg" = app.vlc;
    };
  };
}
