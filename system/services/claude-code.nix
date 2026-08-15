# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (system level): the two things that have to be IMPOSED and not merely suggested,
# the lifecycle HOOKS and the GLOBAL RULES every project inherits.
#
# Why in /etc and not in the user's ~/.claude/settings.json: Claude Code WRITES to the user's
# settings.json at runtime (/config, permission approvals), so it can NOT become a read-only
# symlink into the store. The MANAGED file (/etc) has the highest precedence, accepts hooks (the
# same format) and is read-only by nature, so it is the only 100% declarative place that does not
# fight CC's writes.
#
# THE HOOKS: these 6 events feed the Discord Rich Presence: the hook POSTs the event to the local
# daemon (home/claude-discord-rpc.nix), which paints the card on Discord. The format is identical
# to what `claude-presence setup` would write, only declared.
#
# THE GLOBAL RULES (CLAUDE.md, 15/08/2026) are rule 3 applied to the agent contract. The three
# mandatory ones (incremental commits, everything in en-US, never a `Co-Authored-By:`) were being
# RETYPED BY HAND at the top of every prompt, which is the definition of manual: it works until
# the day I forget, and what comes out of that day is a repo in two languages with one blob commit
# signed by a coauthor. Declared once here, every project on this machine is born with them.
#
# WHY /etc/claude-code/CLAUDE.md AND NOT $CLAUDE_CONFIG_DIR/CLAUDE.md, which is the path everybody
# knows: the user one is PER ACCOUNT, so with two accounts (home/shell/claude-code.nix) it would
# be two copies of the same text drifting apart, and CC WRITES to it, because the `#` shortcut
# appends a memory to exactly that file. Nix owning it would break the shortcut and rule 14 (two
# owners on one artifact). The managed one CC only ever READS.
#
# MEASURED on 2.1.222, in the bundle itself, because a memory file that is never read fails
# SILENTLY and looks exactly like a rule being ignored: the memory loader resolves "Managed" to
# `join(fU(), "CLAUDE.md")` and `fU()` returns "/etc/claude-code" on Linux ("/Library/Application
# Support/ClaudeCode" on macOS). It is read UNCONDITIONALLY, unlike the User and Project layers,
# which are gated by settings. It does not REPLACE the project's CLAUDE.md, it loads alongside it.
#
# DISCARDED, and it is the near miss: managed-settings.json has a `claudeMd` STRING field
# ("instructions injected as organization-managed memory. Only honored from managed/policy
# settings"), which does the same job with no second file. It loses on the diff: the markdown
# would become a JSON one-liner with escaped newlines, unreadable in a `git diff` and unreachable
# for markdownlint. Same effect, worse to maintain.
#
# KEEP IT SHORT. This text enters the context of EVERY conversation on this machine, this repo's
# included. It is the most expensive documentation in the repo per line, so it holds the rules and
# nothing else: the reasoning behind them lives in docs/rules.md, which whoever needs it can read.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, pkgs, ... }:

let
  ccds = pkgs.claude-code-discord-status;
  hookScript = "${ccds}/lib/node_modules/claude-code-discord-status/src/hooks/claude-hook.sh";

  # CC runs the hook with the user's PATH (which may not have jq), so we wrap it with the tools
  # guaranteed on the PATH. `exec` means the wrapper disappears and the real script is left.
  hook = pkgs.writeShellApplication {
    name = "claude-presence-hook";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      curl
      jq
      nodejs
    ];
    text = ''exec ${hookScript} "$@"'';
  };
  cmd = lib.getExe hook;

  # Helpers reproducing the shape of upstream's hooks (sync on SessionStart; async, so it does not
  # block CC, on the rest). asyncHook with no matcher omits the key.
  syncHook = {
    matcher = "";
    hooks = [
      {
        type = "command";
        command = cmd;
        timeout = 5;
      }
    ];
  };
  asyncHook =
    matcher:
    (lib.optionalAttrs (matcher != null) { inherit matcher; })
    // {
      hooks = [
        {
          type = "command";
          command = cmd;
          timeout = 5;
          async = true;
        }
      ];
    };
in
{
  # The MANAGED memory: the rules every project on this machine inherits, with no prompt repeating
  # them. Markdown because that is the format CC parses; the numbering here is NOT the numbering in
  # docs/rules.md (that one is API, this one is a list of three).
  environment.etc."claude-code/CLAUDE.md".text = ''
    # Rules for every project on this machine

    Managed memory, declared in `system/services/claude-code.nix`. It holds for every
    account and every repository, and a project's own `CLAUDE.md` refines it instead of
    contradicting it. Changing a rule here means editing that module and rebuilding, never
    editing this file.

    ## Mandatory

    1. **Incremental commits.** One commit per feature or task, along the way, never a
       single blob at the end of the day. The history is the record that explains WHY a
       decision was made, and a blob erases it.
    2. **Everything in en-US**: code, comments, documentation, READMEs, commit messages and
       technical names. The reason is reach, not style: these repositories are public and
       meant to be read by people who do not speak Portuguese.
    3. **No coauthor attribution.** Never a `Co-Authored-By:` trailer, for Claude or for any
       other tool, in a commit or in a pull request. Who typed is not who decided.

    ## How to work

    Move PROGRESSIVELY: leave the repository building, running and committed as you advance,
    instead of changing everything at once and validating only at the end.

    In STUDY projects, help me organize, explain and plan, but do not replace the practical
    part. Implementing it and getting it wrong myself is the point of those repositories.
  '';

  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    hooks = {
      SessionStart = [ syncHook ];
      UserPromptSubmit = [ (asyncHook null) ];
      PreToolUse = [ (asyncHook "Write|Edit|Bash|Read|Grep|Glob|WebSearch|WebFetch|Task") ];
      Stop = [ (asyncHook null) ];
      Notification = [ (asyncHook null) ];
      SessionEnd = [ (asyncHook null) ];
    };
  };
}
