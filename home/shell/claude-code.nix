# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (CLI): the package plus the SEPARATE ACCOUNTS (`claude-fai`,
# `claude-pessoal`).
#
# THE PROBLEM: there are TWO subscriptions on the same machine (FAI/nonprofit and personal)
# and Claude Code keeps the LOGIN, the MCP servers and the settings in a single config
# directory. Running both in the same directory would mean logging in again on every switch.
# The way out is the CLAUDE_CONFIG_DIR variable: each account gets its own directory, and
# switching accounts means switching the variable.
#
#   ~/.claude-fai      -> FAI / nonprofit (victor.ferreira@fai.ufscar.br), the DEFAULT
#   ~/.claude-pessoal  -> personal        (dragons10021@outlook.com)
#   ~/.claude          -> NOT an account: it is the shared ARCHIVE (projects/), see below
#
# THERE ARE TWO ACCOUNTS AND NOT THREE, and that is a correction from 11/08/2026: the first
# version of this module created an EMPTY `~/.claude-fai` next to `~/.claude`, which already
# was the FAI account (`oauthAccount.emailAddress` = victor.ferreira@…, a nonprofit premium
# seat). That would be two logins for the same subscription, and the third "account" would
# exist purely by accident of naming. Now plain `claude` LANDS ON FAI, because
# CLAUDE_CONFIG_DIR is exported into the session (further down). It holds for everything that
# calls the binary without going through the wrappers: the VS Code extension, a script, cron.
# Whoever wants the other account calls `claude-pessoal`, which overrides the variable.
#
# BUT THE ARCHIVE STAYS IN ~/.claude, and that separation is the core of the design: the
# `projects/` (transcripts plus memory, 200 MB and 13 projects here) belongs to the MACHINE,
# not to a subscription. Leaving it on the canonical path means third party tooling that looks
# for the standard (`ccusage` and friends) finds it by itself, and that retiring an account one
# day does not orphan the archive.
#
# AND THAT IS WHY ~/.claude CANNOT BE THE CONFIG FOLDER, however tempting it looks now that it
# already is FAI: the `.claude.json` (project/MCP config, distinct from settings.json) lives at
# the ROOT of CLAUDE_CONFIG_DIR. Without the variable it is the home's `~/.claude.json`; with
# it pointed at `~/.claude` it would become `~/.claude/.claude.json`, a SECOND file diverging
# from the first. Verified on 2.1.222: along with the symlink test, `claude mcp add` wrote
# exactly inside CLAUDE_CONFIG_DIR.
#
# A WRAPPER and not an ALIAS (it was an alias on Arch, in home/.zshrc): an alias only exists in
# an INTERACTIVE zsh, so `claude-fai` did not work over non-interactive SSH, inside a script,
# in a VS Code task or in a Hyprland keybind. The wrapper is a binary on the PATH and rule 7
# asks for the logic in the build. For free, the claude version gets PINNED in the wrapper (the
# package's own store path) instead of depending on which `claude` the PATH resolves first,
# which matters here because this machine has an orphan native install in ~/.local/bin (the one
# `claude doctor` complains about).
#
# HISTORY AND MEMORY ARE SHARED, on purpose: each account's `projects/` is a symlink to the
# canonical archive ~/.claude/projects, which is where the transcripts AND the per-project
# memory live (…/projects/<slug>/memory/). That way any account resumes the same conversations
# and reads the same memories. On Arch this was the `_claude_share_projects` function in
# .zshrc, imperative and running on every shell open; here it is the symlink declared below
# (rule 3). A price to know: `ccusage` does not separate cost per account, because it reads the
# shared archive.
#
# THE SETTINGS.JSON IS VERSIONED IN THE REPO (mkOutOfStoreSymlink), the same contract as VS
# Code (home/apps/vscode.nix) and hyprland.lua: the target is the REAL file in the repo,
# mutable, so the TUI's `/config` keeps working and every adjustment lands as a `git diff`
# instead of invisible drift (rule 16). A `programs.*` generating into the store does NOT work,
# because the store is read-only and CC writes to that file.
#
# WHAT MAKES THAT SAFE, MEASURED on 11/08/2026 on 2.1.222, and it is the detail that decides
# the design: CC writes settings.json ATOMICALLY (tmp plus rename), and a rename over a symlink
# would REPLACE the link with a regular file, disconnecting the repo silently. But it resolves
# the realpath FIRST: the link survived intact and what changed inode was the TARGET file
# (593793 to 593844, through `claude auto-mode reset`), which means the write reaches the repo.
# If CC ever loses that guard, the symptom is ~/.claude-fai/settings.json no longer being a
# symlink and the repo no longer receiving the changes.
#
# THE CONTENT of the settings-*.json: the personal one came from Arch whole; the FAI one is a
# MERGE of the Arch one with what `~/.claude` (the same account, alive on this machine) had in
# use, the `github`/`atlassian`/`frontend-design` plugins. Taking only the Arch version would
# have SILENTLY turned off three plugins that were on, which is the kind of loss nobody
# connects to the migration two days later.
# Other than that, it died in the crossing (rule 16): the `permissions.allow` with
# `mcp__pencil` and the two user MCP servers that were in both accounts' .claude.json, `pencil`
# (/opt/pencil-dev-bin/…, an AUR package that does not exist here) and `atlassian` (through
# `npx mcp-remote`, today done by the atlassian@claude-plugins-official PLUGIN). Migrating a
# permission for an MCP server that does not come up would be declaring the nonexistent.
# NO comments INSIDE the JSON, on purpose: CC rewrites the whole file on save (it is not JSONC
# like VS Code's) and would erase any comment, so the why stays here.
# And `theme: dark-ansi` is not neutral, it is as TokyoNight as it gets: it tells the TUI to
# use the terminal's 16 ANSI colors, which in this repo's kitty ALREADY are the my.theme
# palette (rule 9).
#
# MCP PER ACCOUNT (14/08/2026): the Azure MCP Server (`pkgs.azure-mcp`, packaged in ./pkgs)
# enters FAI ONLY, because the cloud is the work one. The personal account has nothing to do
# with it, and 68 extra tools cost context in every session. That is why `mcp` became a field of
# `profiles`: the account that declares nothing gets no flag.
#
# THE DELIVERY is the wrapper's `--mcp-config` flag, and the three alternatives were DISCARDED
# for a concrete reason:
#   • the repo root's `.mcp.json` (which today serves the two Cloudflare MCP servers) is
#     PROJECT scope: Azure would only exist when running `claude` inside the dotfiles, which is
#     where we will NEVER touch Azure.
#   • user scope in `.claude.json` is app state, and CC rewrites the whole file; declaring
#     there is rule 14's recipe for drift.
#   • `/etc/claude-code/managed-mcp.json` looks like the right place (it is the sibling of the
#     managed-settings.json we already use for the hooks), and it is a TRAP: whoever deploys
#     that file gains EXCLUSIVE control, and CC stops loading EVERYTHING else, including the
#     MCP servers of the `github` and `atlassian` plugins, which are in use. It would gain
#     Azure and lose two.
#
# AND THAT IS WHY PLAIN `claude` BECAME A WRAPPER TOO (it used to be the package's raw binary):
# plain `claude` IS the FAI account (the CLAUDE_CONFIG_DIR down here), so without this the Azure
# MCP would only appear for whoever remembered to type `claude-fai`, and never in the VS Code
# extension, which calls the binary from the PATH. The `claude` package no longer enters
# `home.packages` (two `bin/claude` would collide at activation); it is only referenced by
# `lib.getExe` inside the wrappers.
#
# WHAT DOES NOT GO IN HERE:
#   • `.credentials.json` (each account's OAuth token), which is a secret AND state: never
#     versioned, never declared. A new account means one `/login` (rules 6 and 12).
#   • `.claude.json`, `history.jsonl`, `sessions/`, `plugins/`, `cache/`, which are app state
#     written at runtime; they go to restic, not to git (rule 6).
#   • the lifecycle HOOKS (Discord Rich Presence), which live in
#     /etc/claude-code/managed-settings.json (system/services/claude-code.nix), because they
#     need to be IMPOSED and not overridable. The path is FIXED in /etc, outside
#     CLAUDE_CONFIG_DIR, so they hold for both accounts at once.
#   • the `projects/` of ~/.claude, which is the TARGET of the symlinks, not a declared
#     artifact. Nix owns the links; the content belongs to the app (rule 14).
#   • the REST of ~/.claude (history.jsonl, settings.json, sessions/, shell-snapshots/ and so
#     on), leftover from when it was an account, and leftover is LEGACY: what was worth keeping
#     was copied to ~/.claude-fai at the turn and the rest gets pruned once the new account
#     proves it walks (it is noted in docs/open-items.md, rule 16).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  claude = pkgs.unstable.claude-code;

  # The path of the CLONED repo, the same literal (and the same reason) as
  # home/apps/vscode.nix: it cannot be derived from the evaluation, because the flake is copied
  # into the store. A repo elsewhere means a dangling symlink and CC unable to save settings.
  repo = "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/shell/claude";

  # The Azure MCP Server: it lets CC create, read and change Azure resources through tools
  # instead of clicking in the portal. `--mode namespace` (azmcp's default) exposes ONE tool per
  # service, 68 in total; `all` would explode into hundreds and `single` would leave just one,
  # with an extra routing hop. To trim it down, `--namespace storage --namespace keyvault…`
  # limits it to the named services. Auth does NOT live here (rule 12): it is azmcp's own device
  # code, kept in the keyring, see the comment in pkgs/azure-mcp.nix.
  azureMcp = pkgs.writeText "mcp-azure.json" (
    builtins.toJSON {
      mcpServers.azure = {
        type = "stdio";
        command = lib.getExe pkgs.azure-mcp;
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

  # The accounts' SSOT (rule 11): this attrset generates the wrappers, the claude-pick menu,
  # the settings.json symlinks, the projects/ ones and which MCP servers each account sees. A
  # new account means one entry here plus the settings-<name>.json in ./claude, and nothing
  # else changes.
  profiles = {
    fai = {
      dir = ".claude-fai";
      label = "FAI      (victor.ferreira@fai.ufscar.br)";
      mcp = [ azureMcp ]; # the work cloud belongs to this account only
    };
    pessoal = {
      dir = ".claude-pessoal";
      label = "Pessoal  (dragons10021@outlook.com)";
      mcp = [ ];
    };
  };

  # Which account plain `claude` is. Both the session's CLAUDE_CONFIG_DIR and the `claude`
  # wrapper come from here; ".claude-fai" used to be written twice, and now it comes from
  # profiles.
  defaultProfile = "fai";
  defaultDir = "${config.home.homeDirectory}/${profiles.${defaultProfile}.dir}";

  # The same binary with CLAUDE_CONFIG_DIR swapped and the account's MCP servers. `exec` means
  # the wrapper leaves the process tree and only the real claude remains (signals and the TUI's
  # TTY arrive directly). "$@" forwards arguments, so `--resume`, `-p …` and `doctor` work just
  # like the raw one.
  #
  # The `--` IS NOT DECORATION, and the rule for when to use it is the opposite of the
  # intuition, MEASURED on 2.1.222: `--mcp-config` is VARIADIC (it accepts N files), so it
  # swallows everything that comes after until it finds a token starting with "-". With no
  # terminator, `claude-fai mcp list` dies with "MCP config file not found: …/mcp" (it read
  # `mcp` and `list` as two more config files). But the `--` only fixes the subcommand case and
  # BREAKS the flag one: with it, `claude-fai --version` opens a SESSION with "--version" as the
  # prompt instead of printing the version. Hence the `case`: what starts with "-" (or nothing,
  # the interactive TUI) goes without the terminator; a bare word (a subcommand or a prompt)
  # goes with it.
  mkLauncher =
    binName: p:
    pkgs.writeShellApplication {
      name = binName;
      text = ''
        export CLAUDE_CONFIG_DIR="$HOME/${p.dir}"
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

  # Lines of "<wrapper path>\tlabel" for fzf: it FILTERS on everything and SHOWS only field 2
  # onward (--with-nth), so the path travels along without appearing on screen. Carrying the
  # WRAPPER (and not the directory, as it used to) is what makes the pick inherit
  # CLAUDE_CONFIG_DIR and the account's MCP servers for free, instead of repeating that logic
  # in here.
  menu = lib.concatMapStringsSep "\n" (
    name: "${lib.getExe launchers.${name}}\t${profiles.${name}.label}"
  ) (lib.attrNames profiles);

  # An interactive selector: pick the account on the spot. `claude-pick [args…]`.
  pick = pkgs.writeShellApplication {
    name = "claude-pick";
    runtimeInputs = [
      pkgs.fzf
      pkgs.coreutils
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
    # The package lives HERE and not in home/packages.nix: an app with its own config owns its
    # package (the same rule as vscode.nix). `unstable` because CC evolves fast, and the NixOS
    # stable would freeze months of features. It goes in WRAPPED (`claudeDefault`), never raw:
    # see the header note about plain `claude` becoming a wrapper.
    claudeDefault
    # ccusage: tokens and cost for the 5h block and per session (the claude-usage* aliases
    # below). It only exists in unstable. It reads the ~/.claude/projects archive, which is the
    # SHARED one, so the account disappears from the report: the number belongs to the machine,
    # not to the subscription.
    pkgs.unstable.ccusage
    pick
    # The SAME binary the MCP runs, now also as a command. It is not convenience: the Azure
    # login (a device code) HAS to happen outside Claude Code, because inside the session the
    # code would come out on the MCP server's stderr, where nobody reads. The closure cost is
    # ZERO: mcp-azure.json already references that store path, so this only puts a link on the
    # PATH.
    pkgs.azure-mcp
  ]
  ++ lib.attrValues launchers;

  # Per account: the settings.json linked to the repo (config, versioned) and the projects/
  # pointed at the shared archive (state, shared). `home.file` OWNS both symlinks; what writes
  # INSIDE them is the app, which satisfies rule 14, because the targets are not in the store.
  #
  # The activation FAILS if ~/.claude-<account>/projects already exists as a real directory
  # ("existing file would be clobbered"): when restoring an account backup, restore the CONTENT
  # into ~/.claude/projects, never the account folder.
  home.file = lib.mkMerge (
    lib.mapAttrsToList (name: p: {
      "${p.dir}/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${repo}/settings-${name}.json";
      "${p.dir}/projects".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/projects";
    }) profiles
  );

  # Plain `claude` becomes FAI. Without this it would land in ~/.claude, which today is only the
  # archive, and CC would create a parallel `.claude.json` in there and ask for a third login
  # (see the header note). It holds for everyone who calls the binary without going through the
  # wrappers: the VS Code extension, a script, cron.
  #
  # IT ONLY TAKES EFFECT AFTER LOGGING BACK INTO THE GRAPHICAL SESSION. A new terminal is NOT
  # enough, and that was MEASURED on 11/08/2026, with the switch already applied and the
  # variable still empty in a freshly opened zsh. The mechanism: this is written into
  # `hm-session-vars.sh`, which `~/.zshenv` loads, and the file guards itself with
  # `__HM_SESS_VARS_SOURCED=1` so it does not reload in a subshell. The mark is EXPORTED, so
  # every child of the graphical session is born with it and skips the whole load, which means
  # a new variable does not reach a new terminal, only a new session. Proven with
  # `env -u __HM_SESS_VARS_SOURCED zsh -i -c`: without the mark, it appears.
  # The same family as the NH_FLAKE trap (home/shell/zsh.nix, 03/08).
  #
  # I TRIED `programs.zsh.sessionVariables` as a second layer and it does NOT help: it lands in
  # the SAME ~/.zshenv and brings its own guard (`__HM_ZSH_SESS_VARS_SOURCED`), which the
  # session also exports already, even with the repo not using the option anywhere, because
  # home-manager always emits the block, just empty. It was two layers with the same flaw; one
  # honest layer remained.
  #
  # UNTIL THE RELOGIN, what delivers the right account is the WRAPPER (`claude-fai`), which
  # exports the variable itself. That is the strongest argument for the wrapper existing: it
  # does not depend on the session environment having been rebuilt.
  home.sessionVariables.CLAUDE_CONFIG_DIR = defaultDir;

  programs.zsh.shellAliases = {
    # A live monitor of the current block (tokens and cost), refreshing once a second.
    claude-usage = "watch -n 1 -c ccusage blocks --active --color";
    # A per-session table: how much each conversation consumed.
    claude-usage-sessions = "ccusage session --color";
  };
}
