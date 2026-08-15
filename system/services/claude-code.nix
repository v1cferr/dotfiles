# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (system level): DECLARED lifecycle hooks.
#
# Why in /etc and not in the user's ~/.claude/settings.json: Claude Code WRITES to the user's
# settings.json at runtime (/config, permission approvals), so it can NOT become a read-only
# symlink into the store. The MANAGED file (/etc) has the highest precedence, accepts hooks (the
# same format) and is read-only by nature, so it is the only 100% declarative place that does not
# fight CC's writes.
#
# These 6 events feed the Discord Rich Presence: the hook POSTs the event to the local daemon
# (home/claude-discord-rpc.nix), which paints the card on Discord. The format is identical to what
# `claude-presence setup` would write, only declared.
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
