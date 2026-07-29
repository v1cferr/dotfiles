# ═══════════════════════════════════════════════════════════════════════════
# DISCORD RICH PRESENCE PRO CLAUDE CODE (nível-usuário) — daemon + config.
#
# Trio do tool: hook (system/claude-code.nix, faz POST dos eventos) → daemon
# (aqui, segura a conexão Discord RPC + servidor HTTP local) → card no Discord.
# Precisa do cliente Discord rodando (home/discord.nix), que expõe o socket IPC.
#
# Tudo declarativo: o pacote vem do overlay (./pkgs), a config é gerada por Nix
# e o daemon roda como serviço systemd --user — SEM o `claude-presence setup`
# imperativo (que mutaria settings.json e subiria o daemon na mão).
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, osConfig, lib, ... }:

let
  ccds = pkgs.claude-code-discord-status;
  daemonEntry = "${ccds}/lib/node_modules/claude-code-discord-status/dist/daemon/index.js";
in
lib.mkIf osConfig.my.services.discord-rpc {
  home.packages = [ ccds ]; # CLI `claude-presence` p/ diagnóstico (status/doctor/preview)

  # Config que o daemon lê (loadConfig → ~/.claude-presence/config.json). O DIRETÓRIO
  # segue gravável p/ o daemon escrever pid/log/aggregate — isso é ESTADO, não config.
  home.file.".claude-presence/config.json".text = builtins.toJSON {
    discordClientId = "1472915568930848829"; # app público padrão do upstream
    daemonPort = 19452; # porta local do daemon (default; o hook usa a mesma)
    preset = "minimal"; # estilo do card de atividade
    daemonPath = daemonEntry; # referenciado só no fallback de autostart do hook
  };

  # Daemon: sobe com a sessão gráfica (Discord vive nela) e auto-reconecta se o
  # Discord abrir/fechar depois. Serviço declarado = não dependemos do autostart
  # imperativo do próprio tool. Não reinicia em loop: sem Discord ele só loga e segue.
  systemd.user.services.claude-presence-daemon = {
    Unit = {
      Description = "Discord Rich Presence do Claude Code (daemon)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.nodejs}/bin/node ${daemonEntry}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
