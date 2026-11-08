# CODEX (system): the declared config as /etc/codex/config.toml, Codex's system layer, under the
# user's ~/.codex/config.toml that Codex and the ChatGPT app write. Why: docs/notes/apps/codex.md
{ ... }:

{
  environment.etc."codex/config.toml".source = ../../home/shell/codex/config.toml;
}
