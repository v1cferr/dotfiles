# ═══════════════════════════════════════════════════════════════════════════
# ESCRITÓRIO — ONLYOFFICE Desktop Editors.
#
# Escolha do stack: o OnlyOffice usa OOXML como formato NATIVO, então .docx/.xlsx/
# .pptx abrem sem tabela deslocada nem repaginação — e a UI é ribbon, igual ao
# Office 365. O LibreOffice é o default da comunidade NixOS e tem mais recursos
# (Draw/Base/macros), mas é nativo em ODF e converte OOXML, perdendo fidelidade em
# documento complexo. Trocar = 1 linha aqui + os defaults abaixo.
#
# As FONTES vêm do system/hardware/fonts.nix (corefonts + vista-fonts): o pacote é
# buildFHSEnv e o /etc/fonts vem do HOST (build-fhsenv-bubblewrap), então fontconfig
# do sistema já enxerga — NÃO precisa do "copie os .ttf p/ ~/.local/share/fonts" que
# o wiki do NixOS manda fazer à mão (regra 3).
#
# PEGADINHA: o .desktop do OnlyOffice reivindica 61 mimetypes, incluindo pdf, epub,
# text/plain, markdown e csv. Os defaults explícitos de home/apps/media.nix (Okular)
# e home/desktop/xdg.nix (VS Code) continuam ganhando — mas se algum dia sumirem, o
# OnlyOffice passa a abrir PDF e .txt.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:

let
  office = "onlyoffice-desktopeditors.desktop";
in
{
  home.packages = [ pkgs.onlyoffice-desktopeditors ];

  # Apps padrão por tipo (funde com media.nix e xdg.nix num só mimeapps.list).
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # ── OOXML (Office 2007+) ──
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = office; # .docx
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = office; # .xlsx
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" = office; # .pptx
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow" = office; # .ppsx
      # ── Binários legados (Office ≤2003) ──
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
