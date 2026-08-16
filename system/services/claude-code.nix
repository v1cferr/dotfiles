# CLAUDE CODE (system): the 2 things that have to be IMPOSED, the lifecycle HOOKS and the managed
# CLAUDE.md every project inherits. Why /etc and not the user's dir: docs/notes/claude-code.md
{ lib, pkgs, ... }:

let
  ccds = pkgs.claude-code-discord-status;
  hookScript = "${ccds}/lib/node_modules/claude-code-discord-status/src/hooks/claude-hook.sh";

  # CC runs the hook with the USER's PATH (which may not have jq), so it is wrapped with the tools
  # guaranteed on the PATH. `exec` makes the wrapper disappear and leaves the real script.
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
}
