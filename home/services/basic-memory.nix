# BASIC MEMORY: ONE MCP server over ~/context, which the three agent CLIs share.
# Why HTTP and not stdio, and who owns the 88 settings: docs/notes/apps/basic-memory.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  cfg = config.my.memory;
in
{
  # The SSOT the CLIs read (rule 11): the clients never hold the port or the path as a literal.
  options.my.memory = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "Loopback port where the MCP memory server listens.";
    };

    dir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/context";
      description = "The Markdown knowledge base. It is the source of truth; the index is derived.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://127.0.0.1:${toString cfg.port}/mcp";
      description = "The endpoint every MCP client points at. Derived, never set by hand.";
    };
  };

  config = lib.mkIf osConfig.my.services.basic-memory {
    # The CLI travels with the server: `bm import`, `bm tool` and `bm doctor` are the human side.
    home.packages = [ pkgs.basic-memory ];

    systemd.user.services.basic-memory = {
      Unit = {
        Description = "Basic Memory: the MCP knowledge server over ${cfg.dir}";
        # No graphical session: an agent over SSH needs this as much as one in the terminal here.
        After = [ "default.target" ];
      };

      Service = {
        # The server creates the project on its first start, but not the directory it points at.
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.dir}";
        ExecStart = "${lib.getExe pkgs.basic-memory} mcp --transport streamable-http --host 127.0.0.1 --port ${toString cfg.port}";

        # THE ENVIRONMENT IS THE CONFIG (rule 14). `~/.basic-memory/config.json` holds all 88
        # settings and the app rewrites it, so what I own is declared here and it WINS: `bm config
        # get auto_update` answers "Overridden by $BASIC_MEMORY_AUTO_UPDATE".
        Environment = [
          "BASIC_MEMORY_HOME=${cfg.dir}"
          "BASIC_MEMORY_DEFAULT_PROJECT=main"
          # Every project stays under ~/context, so an agent cannot point the knowledge base at
          # some other corner of my home.
          "BASIC_MEMORY_PROJECT_ROOT=${cfg.dir}"
          # The store is read-only, so its updater can only nag. `update` is what bumps this.
          "BASIC_MEMORY_AUTO_UPDATE=false"
          # PINNED and not left implicit: it is what makes an edit in Obsidian reach the index,
          # which is the whole point of the shared directory, and a default is upstream's to change.
          "BASIC_MEMORY_INDEX_CHANGES=true"
        ];

        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
