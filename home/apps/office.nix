# OFFICE: ONLYOFFICE Desktop Editors.
#
# The stack choice: OnlyOffice uses OOXML as its NATIVE format, so .docx/.xlsx/.pptx open with no
# shifted table and no repagination, and the UI is a ribbon, just like Office 365. LibreOffice is
# the NixOS community's default and has more features (Draw/Base/macros), but it is native in ODF
# and converts OOXML, losing fidelity on a complex document. Switching = 1 line here plus the
# defaults below.
#
# The FONTS come from system/hardware/fonts.nix (corefonts plus vista-fonts): the package is a
# buildFHSEnv and /etc/fonts comes from the HOST (build-fhsenv-bubblewrap), so the system's
# fontconfig already sees them; there is NO need for the "copy the .ttf into
# ~/.local/share/fonts" the NixOS wiki tells you to do by hand (rule 3).
#
# A TRAP: OnlyOffice's .desktop claims 61 mimetypes, pdf, epub, text/plain, markdown and csv
# included. The explicit defaults in home/apps/media.nix (Okular) and home/desktop/xdg.nix
# (VS Code) still win, but if they ever disappear, OnlyOffice starts opening PDFs and .txt files.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  office = "onlyoffice-desktopeditors.desktop";
in
{
  home.packages = [ pkgs.onlyoffice-desktopeditors ];

  # The default apps per type (it merges with media.nix and xdg.nix into a single mimeapps.list).
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
