# BASIC MEMORY, the SYSTEM side: the servers' SSOT (rule 11), read by the tunnel and the clients.
# What RUNS them is home/services/basic-memory.nix. Why two servers: docs/notes/apps/basic-memory.md
{ lib, ... }:

{
  options.my.memory.servers = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { config, ... }:
        {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
              description = "Loopback port where this server listens.";
            };
            projects = lib.mkOption {
              type = lib.types.nonEmptyListOf lib.types.str;
              description = "Scope directories under knowledge/, one Basic Memory project each.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "http://127.0.0.1:${toString config.port}/mcp";
              description = "The endpoint an MCP client points at. Derived, never set by hand.";
            };
          };
        }
      )
    );
    # Split at the FAI boundary: general never indexes a FAI file, so it cannot return one.
    default = {
      general = {
        port = 8765;
        projects = [
          "personal"
          "study"
          "projects"
        ];
      };
      fai = {
        port = 8766;
        projects = [ "fai" ];
      };
    };
    description = "The Basic Memory servers, each with its own config directory and index.";
  };
}
