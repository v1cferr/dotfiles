# MEDIA: Gwenview (KDE), PdfCraft for documents, plus mpv (uosc UI) as THE player.
# ALWAYS the CANONICAL mimetype, never an alias: docs/notes/apps/apps-and-mime.md
{ pkgs, ... }:

let
  # The apps' .desktop files, used only in the associations below.
  app = {
    gwenview = "org.kde.gwenview.desktop";
    pdfcraft = "ai.storyteller.pdfcraft.desktop";
    mpv = "mpv.desktop";
  };

  # My oldest playlist, still updated today. Named once: two aliases below read it.
  playlist = "https://www.youtube.com/playlist?list=PLFxBBkriBXUVCKyD3LKYZRAACJX67A-ng";

  # 1080p ceiling. av01 is NO LONGER excluded: that was an NVIDIA-era workaround and the Arc
  # B580 decodes AV1 in hardware (`vainfo`: VAProfileAV1Profile0, VAEntrypointVLD).
  ytFormat = "bestvideo[height<=1080]+bestaudio/best[height<=1080]";
  ytRetries = "extractor-retries=3,fragment-retries=3,retries=3"; # a flaky CDN is the normal case
  # hwdec and vo are ABSENT on purpose: they belong to programs.mpv below, one owner (rule 14).
  ytVideo = ''mpv --profile=fast --cache=yes --ytdl-raw-options="${ytRetries}" --ytdl-format="${ytFormat}"'';
  ytAudio = "mpv --no-video --force-window=no --ytdl-format=bestaudio";
in
{
  home.packages = with pkgs; [
    kdePackages.gwenview # an image viewer (KDE): basic editing plus thumbnails
    pdfcraft # the ONE PDF reader and editor (Rust/egui), the vendored release binary, pkgs/pdfcraft
    kdePackages.kimageformats # format plugins for KDE apps: AVIF/HEIF/JXL/PSD/RAW
    kdePackages.qtimageformats # Qt plugins: WebP/TIFF/ICNS (it complements kimageformats)
  ];

  # mpv: the ONE player (Wayland native, VA-API on the Arc); uosc gives it a modern GUI.
  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      uosc # the modern on-screen controls (menus, playlist, tracks)
      thumbfast # thumbnails on the uosc seek bar
      mpris # media keys plus the bar's player widget
    ];
    config = {
      hwdec = "auto-safe"; # it decodes on the GPU when that is safe (it spares the CPU)
      vo = "gpu-next"; # a modern video output (better HDR/tone-mapping on Wayland)
      osc = "no"; # uosc replaces the built-in OSC (it requires this off)
      osd-bar = "no"; # uosc draws its own volume/seek feedback
      border = "no"; # uosc draws the window controls
      keep-open = "yes"; # the last frame stays instead of the window closing
      save-position-on-quit = "yes"; # reopen a file where it stopped
    };
  };

  # The YouTube aliases, next to the tool that runs them (the flameshot.nix convention).
  # `yttui` did NOT come back: it aliased a `yt` binary this tree does not declare.
  programs.zsh.shellAliases = {
    ytmix = ''${ytAudio} --save-position-on-quit=no --shuffle "${playlist}"''; # the playlist, audio only
    ytvideo = ''${ytVideo} --shuffle "${playlist}"''; # the playlist, up to 1080p
    ytaudio = ytAudio; # any link, audio only (a URL is the argument)
    ytwatch = ytVideo; # any link, up to 1080p
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
      "application/pdf" = app.pdfcraft; # .cbz has NO default since Papers left (docs/notes/apps/pdfcraft.md)
      # Video.
      "video/mp4" = app.mpv; # .mp4/.m4v
      "video/x-matroska" = app.mpv; # .mkv
      "video/webm" = app.mpv;
      "video/quicktime" = app.mpv; # .mov
      "video/vnd.avi" = app.mpv; # .avi; it used to be video/x-msvideo, which is only an ALIAS, so it never matched
      "video/mpeg" = app.mpv;
      "video/x-flv" = app.mpv; # .flv
      "video/x-ms-wmv" = app.mpv; # .wmv
      "video/3gpp" = app.mpv; # .3gp
      "video/ogg" = app.mpv; # .ogv
      # Audio, listed explicitly so the choice is declared, not left to what .desktop files claim.
      "audio/mpeg" = app.mpv; # .mp3
      "audio/flac" = app.mpv;
      "audio/ogg" = app.mpv; # .ogg/.opus
      "audio/vnd.wave" = app.mpv; # .wav
      "audio/mp4" = app.mpv; # .m4a
      "audio/aac" = app.mpv;
      "audio/x-ms-wma" = app.mpv; # .wma
      "audio/x-matroska" = app.mpv; # .mka
      "audio/midi" = app.mpv; # .mid
    };
  };
}
