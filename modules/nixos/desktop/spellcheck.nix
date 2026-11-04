# SPELLCHECK: the SSOT of the spellcheck languages, `my.spellcheck.languages`, plus the hunspell
# dictionaries every engine reads. One layer per app family: docs/notes/desktop/spellcheck.md
{
  pkgs,
  lib,
  config,
  ...
}:

let
  inherit (pkgs) hunspellDicts;

  # hunspellDicts names them with an underscore (en_US), BCP 47 with a hyphen (en-US).
  dicts = map (
    l: hunspellDicts.${lib.replaceStrings [ "-" ] [ "_" ] l}
  ) config.my.spellcheck.languages;
in
{
  options.my.spellcheck.languages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "en-US"
      "pt-BR"
    ];
    description = "The spellcheck languages as BCP 47 tags (SSOT). Read by every layer, and by modules/home/ through osConfig.";
  };

  config = {
    environment = {
      systemPackages = dicts;
      # Gecko and enchant (GTK's gspell/libspelling, Qt's Sonnet) look for .dic/.aff here.
      sessionVariables.DICPATH = "/run/current-system/sw/share/hunspell";
    };

    # Chrome's managed policy (/etc/opt/chrome/policies, every channel): only writes the JSON,
    # installs no browser. Locked, so a click in Settings cannot drop a language.
    programs.chromium = {
      enable = true;
      extraOpts = {
        SpellcheckEnabled = true;
        SpellcheckLanguage = config.my.spellcheck.languages;
      };
    };
  };
}
