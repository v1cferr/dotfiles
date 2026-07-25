# ═══════════════════════════════════════════════════════════════════════════
# CLAUDE CODE (nível-sistema) — hooks de ciclo de vida DECLARADOS.
#
# Por que em /etc e não no ~/.claude/settings.json: o Claude Code ESCREVE no
# settings.json do usuário em runtime (/config, aprovações de permissão), então
# ele NÃO pode virar symlink read-only da store. O arquivo MANAGED (/etc) tem a
# maior precedência, aceita hooks (mesmo formato) e é read-only por natureza —
# é o único lugar 100% declarativo que não briga com os writes do CC.
#
# Estes 6 eventos alimentam o Discord Rich Presence: o hook faz POST do evento
# pro daemon local (home/claude-discord-rpc.nix), que pinta o card no Discord.
# Formato idêntico ao que o `claude-presence setup` gravaria — só que declarado.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, pkgs, ... }:

let
  ccds = pkgs.claude-code-discord-status;
  hookScript = "${ccds}/lib/node_modules/claude-code-discord-status/src/hooks/claude-hook.sh";

  # O CC roda o hook com o PATH do usuário (pode não ter jq) → embrulhamos com as
  # ferramentas garantidas no PATH. `exec` = o wrapper some, sobra o script real.
  hook = pkgs.writeShellApplication {
    name = "claude-presence-hook";
    runtimeInputs = with pkgs; [ bash coreutils curl jq nodejs ];
    text = ''exec ${hookScript} "$@"'';
  };
  cmd = lib.getExe hook;

  # Helpers que reproduzem a forma dos hooks do upstream (sync no SessionStart;
  # async — não bloqueia o CC — no resto). asyncHook sem matcher omite a chave.
  syncHook = {
    matcher = "";
    hooks = [ { type = "command"; command = cmd; timeout = 5; } ];
  };
  asyncHook =
    matcher:
    (lib.optionalAttrs (matcher != null) { inherit matcher; })
    // {
      hooks = [ { type = "command"; command = cmd; timeout = 5; async = true; } ];
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
