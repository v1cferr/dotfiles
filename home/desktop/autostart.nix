# ═══════════════════════════════════════════════════════════════════════════
# PAINEL DE AUTOSTART — o que ABRE junto com a sessão gráfica, num lugar só.
# Editar true/false no painel abaixo + `rebuild`. Espelha o idioma do
# system/services/toggles.nix (mkEnableOption + gate), mas p/ APPS de GUI.
#
# ÍNDICE — o que sobe no boot mora em TRÊS lugares, por motivos diferentes:
#   1. AQUI (my.autostart)      → apps de GUI sem módulo próprio: Discord, Spotify.
#   2. my.services.<n>          → serviços de verdade, com módulo/daemon próprio
#      (system/services/toggles.nix)  (dropbox, jellyfin, ollama, sunshine, restic…).
#   3. hypr/lua/autostart.lua   → infra da sessão que PRECISA do exec-once do
#      compositor: hyprlock (a máquina sobe travada), quickshell (barra) e
#      wl-clip-persist. Não migrei p/ systemd porque o hyprlock no boot é
#      load-bearing p/ o acesso remoto (o Moonlight cai no lockscreen).
#
# POR QUE SERVIÇO E NÃO exec-once: `exec-once` NÃO reinicia se o app morrer. Serviço
# systemd reinicia. Restart=on-failure de propósito: crash volta, mas FECHAR na mão
# respeita a decisão (Electron sai com 0 ao fechar). Com `always` você não conseguiria
# fechar o app — ele voltaria em segundos.
#
# Os pacotes vêm de home/packages.nix; aqui só se REFERENCIA o binário pelo store path
# (não instala de novo — é o mesmo path, não fere a regra 4).
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Tabela dos apps: adicionar um = 1 entrada aqui + 1 linha no painel abaixo.
  # O binário do Discord é `Discord` (maiúsculo) — é o que o .desktop dele usa.
  apps = {
    discord = {
      exec = "${pkgs.discord}/bin/Discord";
      desc = "chat/voz";
    };
    spotify = {
      exec = "${pkgs.spotify}/bin/spotify";
      desc = "música";
    };
  };

  enabled = lib.filterAttrs (n: _: config.my.autostart.${n}) apps;
in
{
  options.my.autostart = lib.genAttrs (lib.attrNames apps) (n: lib.mkEnableOption n);

  config = {
    # ── PAINEL: edite aqui pra ligar/desligar o que abre no login ─────────────
    my.autostart = {
      discord = true; # chat/voz
      spotify = true; # música
    };

    # Um serviço --user por app habilitado, preso ao graphical-session.target: sobe
    # quando a sessão sobe e cai com ela (não sobrevive a logout como processo órfão).
    systemd.user.services = lib.mapAttrs' (
      name: app:
      lib.nameValuePair "autostart-${name}" {
        Unit = {
          Description = "Autostart: ${name} (${app.desc})";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = app.exec;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      }
    ) enabled;
  };
}
