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
    # Unstable of 02/11/2026 ships a stale node_modules hash (Hydra fails it too, so no cache).
    # Drop the override once unstable's own hash builds again.
    package = unstable.opencode.overrideAttrs (old: {
      node_modules = old.node_modules.overrideAttrs {
        outputHash = "sha256-prx9dX7kUvs/E3zopkaPk5LXh3xJAy5sZeum/W8L7cA=";
      };
    });
    settings.mcp = lib.mkIf osConfig.my.services.basic-memory {
      basic-memory = {
        type = "remote";
        url = osConfig.my.memory.servers.general.url;
      };
    };
    # opencode expands `{file:}` at startup, so only the PATH reaches the store (rule 12).
    # Inert until `sync-secrets` has put the key in the vault.
    settings.provider = lib.mkIf (osConfig.sops.secrets ? openrouter_api_key) {
      openrouter.options.apiKey = "{file:${osConfig.sops.secrets.openrouter_api_key.path}}";
    };
  };
}
