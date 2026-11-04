# SPELLCHECK, the Electron layer: apps with no language setting get the SSOT languages
# (osConfig.my.spellcheck.languages) seeded into their Chromium Preferences. docs/notes/desktop/spellcheck.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs) jq writeShellApplication;

  seed = writeShellApplication {
    name = "spellcheck-seed";
    runtimeInputs = [ jq ];
    runtimeEnv = {
      SPELLCHECK_LANGUAGES = lib.concatStringsSep "\n" osConfig.my.spellcheck.languages;
      SPELLCHECK_PROFILES = lib.concatStringsSep "\n" config.my.spellcheck.electronProfiles;
    };
    text = builtins.readFile ./scripts/seed.sh;
  };
in
{
  # Discord and Obsidian are NOT here: each keeps its own list and rewrites the file (measured).
  options.my.spellcheck.electronProfiles = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "Codex/Default/Preferences" # ChatGPT desktop (its userData is ~/.config/Codex)
    ];
    description = "Chromium Preferences files, relative to XDG_CONFIG_HOME, of Electron apps with no spellcheck language setting.";
  };

  config = {
    home.packages = [ seed ]; # by hand after closing an app that was open at the switch
    home.activation.spellcheckSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe seed}
    '';
  };
}
