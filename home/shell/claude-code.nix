# CLAUDE CODE (CLI): the package plus the two accounts (claude-fai, claude-pessoal).
# Why ~/.claude is the shared archive and not a config dir: docs/notes/apps/claude-code.md
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
    azure-mcp
    coreutils
    fzf
    unstable # the CHANNEL and not a package, so `unstable.x` stays greppable at each use site
    writeShellApplication
    writeText
    ;

  claude = unstable.claude-code;

  # The CLONED repo path: it cannot be derived, since the flake is copied into the store.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/shell/claude";

  # The Azure MCP. `--mode namespace` gives one tool per service (68); auth is azmcp's own
  # device code in the keyring, never here (rule 12).
  azureMcp = writeText "mcp-azure.json" (
    builtins.toJSON {
      mcpServers.azure = {
        type = "stdio";
        command = lib.getExe azure-mcp;
        args = [
          "server"
          "start"
          "--mode"
          "namespace"
        ];
        # Microsoft telemetry off: it is a personal machine, and the server runs locally.
        env.AZURE_MCP_COLLECT_TELEMETRY = "false";
      };
    }
  );

  # The Stitch MCP (Google's UI generator). The key is sops and the launcher puts it in the
  # environment; what lands in the store is the REFERENCE, never the credential (rule 12).
  stitchMcp = writeText "mcp-stitch.json" (
    builtins.toJSON {
      mcpServers.stitch = {
        type = "http";
        url = "https://stitch.googleapis.com/mcp";
        headers."X-Goog-Api-Key" = "\${STITCH_API_KEY}";
      };
    }
  );

  # The SHARED memory (home/services/basic-memory.nix), over HTTP because there is ONE server for
  # the three CLIs. `my.memory.url` is the SSOT; nothing here holds the port.
  memoryMcp = writeText "mcp-basic-memory.json" (
    builtins.toJSON {
      mcpServers.basic-memory = {
        type = "http";
        url = config.my.memory.url;
      };
    }
  );

  # BOTH accounts get it, and that is the point: one memory, not one archive per account. It
  # follows the service's toggle, so a host without the server does not carry a dead endpoint.
  memory = lib.optional osConfig.my.services.basic-memory memoryMcp;

  # The accounts' SSOT (rule 11): wrappers, menu, symlinks and MCP all come from here.
  # A new account = one entry plus its settings-<name>.json.
  profiles = {
    fai = {
      dir = ".claude-fai";
      label = "FAI      (victor.ferreira@fai.ufscar.br)";
      mcp = [
        azureMcp
        stitchMcp
      ]
      ++ memory; # the work cloud and the design tool belong to this account only
    };
    pessoal = {
      dir = ".claude-pessoal";
      label = "Pessoal  (dragons10021@outlook.com)";
      mcp = memory;
    };
  };

  # Which account plain `claude` is; both the env var and the wrapper read it from here.
  defaultProfile = "fai";
  defaultDir = "${config.home.homeDirectory}/${profiles.${defaultProfile}.dir}";

  # The same binary with CLAUDE_CONFIG_DIR swapped. The `case` around `--` is measured: without
  # it `mcp list` breaks, with it always `--version` opens a session. See the note.
  mkLauncher =
    binName: p:
    writeShellApplication {
      name = binName;
      runtimeInputs = [ coreutils ]; # `cat`, for the sops read below
      text = ''
        export CLAUDE_CONFIG_DIR="$HOME/${p.dir}"

        # The Stitch MCP expands $STITCH_API_KEY when it connects, so the key has to be in
        # THIS process. Read here and not exported from the shell: only claude needs it
        # (the `notify` pattern). Absent, Stitch falls back to OAuth and fails on its own
        # without taking the session down. The assignment is split from the export because
        # `X="$(cmd)"` masks the exit code and shellcheck FAILS the build for it (SC2155).
        secret=/run/secrets/stitch_api_key
        if [ -r "$secret" ]; then
          STITCH_API_KEY="$(cat "$secret")"
          export STITCH_API_KEY
        fi
      ''
      + (
        if p.mcp == [ ] then
          ''
            exec ${lib.getExe claude} "$@"
          ''
        else
          let
            flags = lib.concatMapStringsSep " " (f: "--mcp-config ${f}") p.mcp;
          in
          ''
            case "''${1-}" in
              -* | "") exec ${lib.getExe claude} ${flags} "$@" ;;
              *)       exec ${lib.getExe claude} ${flags} -- "$@" ;;
            esac
          ''
      );
    };

  # `claude-fai` / `claude-pessoal`, plus plain `claude` pointing at the default account.
  launchers = lib.mapAttrs (name: mkLauncher "claude-${name}") profiles;
  claudeDefault = mkLauncher "claude" profiles.${defaultProfile};

  # "<wrapper>\tlabel" for fzf: it filters on everything and shows only the label.
  # Carrying the WRAPPER is what makes the pick inherit the account for free.
  menu = lib.concatMapStringsSep "\n" (
    name: "${lib.getExe launchers.${name}}\t${profiles.${name}.label}"
  ) (lib.attrNames profiles);

  # An interactive selector: pick the account on the spot. `claude-pick [args…]`.
  pick = writeShellApplication {
    name = "claude-pick";
    runtimeInputs = [
      fzf
      coreutils
    ];
    text = ''
      # `|| exit 0`: Esc or Ctrl-C in fzf exits with 130 and `set -e` would kill the script with
      # an error, but cancelling the menu is normal use, not a failure.
      sel=$(printf '%s\n' ${lib.escapeShellArg menu} \
        | fzf --prompt='Claude account > ' --height=25% --reverse \
              --delimiter='\t' --with-nth=2..) || exit 0
      # The assignment is separate from the exec: `X="$(cmd)"` on the same line masks the exit
      # code (SC2155), and the writeShellApplication shellcheck FAILS the build for it.
      bin=$(printf '%s' "$sel" | cut -f1)
      exec "$bin" "$@"
    '';
  };
in
{
  home.packages = [
    # The package lives here because the app owns its config. Wrapped, never raw: two
    # bin/claude would collide at activation.
    claudeDefault
    # ccusage reads the SHARED archive, so the report is per machine, not per subscription.
    unstable.ccusage
    pick
    # Also a command, because the device-code login has to happen OUTSIDE a session.
    # Closure cost zero: the MCP config already references this store path.
    azure-mcp
  ]
  ++ lib.attrValues launchers;

  # Per account: settings.json into the repo (config), projects/ into the shared archive
  # (state). Nix owns the links, the app owns what is inside them (rule 14).
  home.file = lib.mkMerge (
    lib.mapAttrsToList (name: p: {
      "${p.dir}/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/settings-${name}.json";
      "${p.dir}/projects".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/projects";
    }) profiles
  );

  # Plain `claude` becomes FAI. It only takes effect after a RELOGIN, never in a new terminal:
  # hm-session-vars.sh guards itself with an EXPORTED mark. Until then, the wrapper delivers.
  home.sessionVariables.CLAUDE_CONFIG_DIR = defaultDir;

  programs.zsh.shellAliases = {
    # A live monitor of the current block (tokens and cost), refreshing once a second.
    claude-usage = "watch -n 1 -c ccusage blocks --active --color";
    # A per-session table: how much each conversation consumed.
    claude-usage-sessions = "ccusage session --color";
  };
}
