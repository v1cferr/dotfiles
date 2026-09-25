# BASIC MEMORY: two MCP servers over the context repo, split at the FAI boundary.
# Why two, why HTTP and who owns the settings: docs/notes/apps/basic-memory.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once. deadnix fails the build on an
  # entry that stops being used, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    basic-memory
    coreutils
    ;

  cfg = config.my.memory;
  knowledge = "${cfg.dir}/knowledge";

  mkServer = name: server: {
    name = "basic-memory-${name}";
    value = {
      Unit = {
        Description = "Basic Memory (${name}): MCP server over ${lib.concatStringsSep ", " server.projects}";
        # No graphical session: an agent over SSH needs this as much as one in the terminal here.
        After = [ "default.target" ];
      };

      Service = {
        ExecStartPre = "${coreutils}/bin/mkdir -p ${
          lib.concatMapStringsSep " " (p: "${knowledge}/${p}") server.projects
        }";
        ExecStart = "${lib.getExe basic-memory} mcp --transport streamable-http --host 127.0.0.1 --port ${toString server.port}";

        # THE ENVIRONMENT IS THE CONFIG (rule 14), and each server's CONFIG_DIR is its own SQLite.
        # The JSON is single-quoted: unquoted, systemd strips its double quotes (measured).
        Environment = [
          "BASIC_MEMORY_CONFIG_DIR=${config.home.homeDirectory}/.basic-memory/${name}"
          "'BASIC_MEMORY_PROJECTS=${
            builtins.toJSON (
              lib.genAttrs server.projects (p: {
                path = "${knowledge}/${p}";
              })
            )
          }'"
          "BASIC_MEMORY_DEFAULT_PROJECT=${builtins.head server.projects}"
          # Projects stay under knowledge/, so an agent cannot index some other corner of my home.
          "BASIC_MEMORY_PROJECT_ROOT=${knowledge}"
          # The store is read-only, so its updater can only nag. `update` is what bumps this.
          "BASIC_MEMORY_AUTO_UPDATE=false"
          # Pinned: it is what makes an edit in Obsidian reach the index, and a default can move.
          "BASIC_MEMORY_INDEX_CHANGES=true"
        ];

        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
in
{
  # The path's SSOT (rule 11); the ports and projects are the system's: system/services/basic-memory.nix
  options.my.memory = {
    dir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/context";
      description = "The context repository. Its Markdown is the source of truth; every index is derived.";
    };
  };

  config = lib.mkIf osConfig.my.services.basic-memory {
    # The CLI travels with the servers: `bm status`, `bm reindex` and `bm doctor` are the human side.
    home.packages = [ basic-memory ];

    systemd.user.services = lib.mapAttrs' mkServer osConfig.my.memory.servers;
  };
}
