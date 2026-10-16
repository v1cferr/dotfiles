# Bitwarden in Vicinae: the bitwarden extension over rbw, whose config is a sops render because it
# holds my email. Unlock, lock timeout and what Paste cannot do: docs/notes/desktop/vicinae.md
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  inherit (pkgs) rbw;

  # Declared only once the vault and the index both hold `rbw_email` (setup steps in the note).
  rbwConfig = osConfig.sops.templates."rbw-config.json".path or null;
in
{
  # On PATH too, for the one-time `rbw login` and for checking `rbw unlocked` by hand.
  home.packages = [ rbw ];

  # A link and not a copy, so the email never reaches the store; rbw only reads this file.
  xdg.configFile = lib.optionalAttrs (rbwConfig != null) {
    "rbw/config.json".source = config.lib.file.mkOutOfStoreSymlink rbwConfig;
  };
}
