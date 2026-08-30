# CLAUDE CODE (system): the 3 things that have to be IMPOSED, the lifecycle HOOKS, the managed
# CLAUDE.md and the shared SKILLS. Why /etc and not the user's dir: docs/notes/apps/claude-code.md
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Every package this module reaches for, named ONCE and up front: an entry that stops being
  # used fails the build under deadnix, so the list cannot rot into a lie (rule 16).
  inherit (pkgs)
    bash
    claude-code-discord-status
    coreutils
    curl
    jq
    nodejs
    writeShellApplication
    ;

  ccds = claude-code-discord-status;
  hookScript = "${ccds}/lib/node_modules/claude-code-discord-status/src/hooks/claude-hook.sh";

  # CC runs the hook with the USER's PATH (which may not have jq), so it is wrapped with the tools
  # guaranteed on the PATH. `exec` makes the wrapper disappear and leaves the real script.
  hook = writeShellApplication {
    name = "claude-presence-hook";
    runtimeInputs = [
      bash
      coreutils
      curl
      jq
      nodejs
    ];
    text = ''exec ${hookScript} "$@"'';
  };
  cmd = lib.getExe hook;

  # Upstream's shape: sync on SessionStart, async on the rest so they do not block CC.
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

  # The skills come from the PINNED input (rule 13), never from a marketplace fetched at runtime.
  # Which ones, and the 3 delivery paths that were rejected: docs/notes/apps/claude-code.md
  skills = "${inputs.mattpocock-skills}/skills/productivity";
in
{
  # The MANAGED memory, read unconditionally by CC and never written to. KEEP IT SHORT: this
  # text enters EVERY conversation on this machine. The reasoning lives in docs/rules.md.
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

  # MANAGED skills, the one layer that reaches BOTH accounts and every repo at once. CC follows a
  # symlink here, so an entry is the store path itself. STATELESS ones only: see the note.
  environment.etc."claude-code/.claude/skills/grill-me".source = "${skills}/grill-me";
  environment.etc."claude-code/.claude/skills/grilling".source = "${skills}/grilling";
}
