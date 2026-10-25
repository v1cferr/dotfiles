# OPENCODE (sst's agent CLI): the package plus its MCP servers, through home-manager's module.
# No note: the app keeps runtime picks in ~/.local/state, so a generated opencode.json is safe.
{
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    ;
in
{
  programs.opencode = {
    enable = true;
    # Layer 2: the 26.05 channel sits a major behind (1.15 against 2.0 on 25/10/2026).
    package = unstable.opencode;
    settings.mcp = lib.mkIf osConfig.my.services.basic-memory {
      basic-memory = {
        type = "remote";
        url = osConfig.my.memory.servers.general.url;
      };
    };
  };
}
