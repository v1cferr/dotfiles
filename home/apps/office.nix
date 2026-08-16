# OFFICE: ONLYOFFICE, whose NATIVE format is OOXML, so a .docx opens without repaginating.
# Why not LibreOffice, the fonts, and the 61-mimetype trap: docs/notes/apps/apps-and-mime.md
{ pkgs, ... }:

let
  office = "onlyoffice-desktopeditors.desktop";
in
{
  home.packages = [ pkgs.onlyoffice-desktopeditors ];

  # It merges with media.nix and xdg.nix into a single mimeapps.list.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # ── OOXML (Office 2007+) ──
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = office; # .docx
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = office; # .xlsx
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = office; # .pptx
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = office; # .ppsx
      # ── The legacy binaries (Office 2003 and earlier) ──
      "application/msword" = office; # .doc
      "application/vnd.ms-excel" = office; # .xls
      "application/vnd.ms-powerpoint" = office; # .ppt
      # ── OpenDocument ──
      "application/vnd.oasis.opendocument.text" = office; # .odt
      "application/vnd.oasis.opendocument.spreadsheet" = office; # .ods
      "application/vnd.oasis.opendocument.presentation" = office; # .odp
      # ── Rich text ──
      "application/rtf" = office; # .rtf
    };
  };
}
