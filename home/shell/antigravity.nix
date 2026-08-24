# ANTIGRAVITY CLI (`agy`): the package plus the one thing worth declaring, its MCP servers.
# Why a merge at activation and never a symlink: docs/notes/apps/antigravity-cli.md
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  mcpFile = "${config.home.homeDirectory}/.gemini/config/mcp_config.json";

  # `serverUrl` and NOT `url`: the legacy key is refused by 1.1.x, and the CLI says nothing when a
  # server fails to parse, it just is not there.
  declared = builtins.toJSON { mcpServers.basic-memory.serverUrl = config.my.memory.url; };
in
{
  home.packages = [
    pkgs.antigravity-cli
    pkgs.antigravity-bump # the `update` alias calls it BY NAME, so it has to be on the PATH
  ];

  # A MERGE and never a generated file: `agy` rewrites this path itself, so Nix owns the keys it
  # declares and leaves the rest alone (rule 14). Idempotent, so every rebuild reasserts it.
  home.activation = lib.mkIf osConfig.my.services.basic-memory {
    antigravityMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      file="${mcpFile}"
      run mkdir -p "$(dirname "$file")"
      # First run leaves the file EMPTY (0 bytes), and jq cannot parse that, so it starts from {}.
      if [ ! -s "$file" ]; then
        run cp ${pkgs.writeText "agy-mcp-config.json" declared} "$file"
        run chmod 600 "$file"
      else
        tmp=$(mktemp)
        # `*` is jq's RECURSIVE merge, so another server already in there survives.
        run ${lib.getExe pkgs.jq} --argjson add ${lib.escapeShellArg declared} '. * $add' "$file" \
          > "$tmp"
        run mv "$tmp" "$file"
      fi
    '';
  };
}
