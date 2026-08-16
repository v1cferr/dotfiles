# MEDIA: the KDE Gear stack (Gwenview/Okular) plus VLC, already themed by Qt/Kvantum.
# ALWAYS the CANONICAL mimetype, never an alias: docs/notes/apps-and-mime.md
{ pkgs, ... }:

let
  # The apps' .desktop files, used only in the associations below.
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

  # mpv: VLC's light, scriptable companion, through its own module (idiomatic).
  programs.mpv = {
    enable = true;
    config = {
      hwdec = "auto-safe"; # it decodes on the GPU when that is safe (it spares the CPU)
      vo = "gpu-next"; # a modern video output (better HDR/tone-mapping on Wayland)
    };
  };

  # The default apps per file type. It merges with xdg.nix and office.nix.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Images. ALWAYS the CANONICAL type: an ALIAS does not match and dies in silence (see notes).
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
      # Documents.
      "application/pdf" = app.okular;
      "application/epub+zip" = app.okular;
      "application/vnd.comicbook+zip" = app.okular; # .cbz
      # Video. mpv is left for opening by hand or from the CLI.
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
      # Audio, listed explicitly: otherwise mpv.desktop takes the association by claiming the types.
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
