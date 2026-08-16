# MEDIA (user level): viewers, players and the DEFAULT apps per type.
#
# The home/ rule (see home/default.nix): a USER app lives here. The stack choice: KDE Gear
# (Gwenview/Okular), because this system is already Qt/Kvantum plus Dolphin, so it comes in themed
# for free and integrates with the file manager (open-with, thumbnails).
# kimageformats plus qtimageformats give the modern formats (AVIF/HEIF/JXL/WebP/RAW).
#
# The xdg.mimeApps associations below MERGE with the ones in home/xdg.nix (the browser), since
# home-manager merges the defaultApplications from every module into a single mimeapps.list.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  # The apps' .desktop files (used only in the type associations below; they do not collide with
  # pkgs)
  app = {
    gwenview = "org.kde.gwenview.desktop";
    okular = "org.kde.okular.desktop";
    vlc = "vlc.desktop";
  };
in
{
  home.packages = with pkgs; [
    kdePackages.gwenview # an image viewer (KDE): basic editing plus thumbnails
    kdePackages.okular # a document reader (KDE): PDF/EPUB/CBZ plus annotations
    kdePackages.kimageformats # format plugins for KDE apps: AVIF/HEIF/JXL/PSD/RAW
    kdePackages.qtimageformats # Qt plugins: WebP/TIFF/ICNS (it complements kimageformats)
    vlc # the do-everything GUI video player (it is the video default, further down)
  ];

  # mpv: a light, scriptable player, VLC's companion. A programs.* module, so idiomatic.
  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe"; # it decodes on the GPU when that is safe (it spares the CPU)
      vo = "gpu-next"; # a modern video output (better HDR/tone-mapping on Wayland)
    };
  };

  # The default apps per file type (declarative). It merges with home/xdg.nix.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # ── Images -> Gwenview ──
      # ALWAYS shared-mime-info's CANONICAL type: an alias does not match in the lookup and the
      # entry dies in silence. (image/heic is an alias of image/heif; Gwenview's .desktop declares
      # only image/x-psd, an alias of image/vnd.adobe.photoshop.)
      "image/png" = app.gwenview;
      "image/jpeg" = app.gwenview;
      "image/gif" = app.gwenview;
      "image/webp" = app.gwenview;
      "image/bmp" = app.gwenview;
      "image/tiff" = app.gwenview;
      "image/svg+xml" = app.gwenview;
      "image/avif" = app.gwenview;
      "image/heif" = app.gwenview; # .heif/.heic
      "image/jxl" = app.gwenview;
      "image/vnd.microsoft.icon" = app.gwenview; # .ico (Qt reads it natively; the .desktop does not declare it)
      "image/vnd.adobe.photoshop" = app.gwenview; # .psd (through kimageformats)
      # ── Documents -> Okular ──
      "application/pdf" = app.okular;
      "application/epub+zip" = app.okular;
      "application/vnd.comicbook+zip" = app.okular; # .cbz
      # ── Video -> VLC (mpv is left for opening manually / from the CLI) ──
      "video/mp4" = app.vlc; # .mp4/.m4v
      "video/x-matroska" = app.vlc; # .mkv
      "video/webm" = app.vlc;
      "video/quicktime" = app.vlc; # .mov
      "video/vnd.avi" = app.vlc; # .avi; it used to be video/x-msvideo, which is only an ALIAS, so it fell into mpv
      "video/mpeg" = app.vlc;
      "video/x-flv" = app.vlc; # .flv
      "video/x-ms-wmv" = app.vlc; # .wmv
      "video/3gpp" = app.vlc; # .3gp
      "video/ogg" = app.vlc; # .ogv
      # ── Audio -> VLC (the same logic as video; without this mpv.desktop took the association by
      # claiming the types in its .desktop, against the intent above) ──
      "audio/mpeg" = app.vlc; # .mp3
      "audio/flac" = app.vlc;
      "audio/ogg" = app.vlc; # .ogg/.opus
      "audio/vnd.wave" = app.vlc; # .wav
      "audio/mp4" = app.vlc; # .m4a
      "audio/aac" = app.vlc;
      "audio/x-ms-wma" = app.vlc; # .wma
      "audio/x-matroska" = app.vlc; # .mka
      "audio/midi" = app.vlc; # .mid
    };
  };
}
