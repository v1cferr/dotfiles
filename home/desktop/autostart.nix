# ═══════════════════════════════════════════════════════════════════════════
# PAINEL DE AUTOSTART — o que ABRE junto com a sessão gráfica, num lugar só.
# Editar true/false no painel abaixo + `rebuild`. Espelha o idioma do
# system/services/toggles.nix (mkEnableOption + gate), mas p/ APPS de GUI.
#
# ÍNDICE — o que sobe no boot mora em TRÊS lugares, por motivos diferentes:
#   1. AQUI (my.autostart)      → apps de GUI sem módulo próprio: Discord, Spotify.
#   2. my.services.<n>          → serviços de verdade, com módulo/daemon próprio
#      (dropbox, jellyfin, ollama, sunshine, restic…). As chaves são declaradas em
#      system/services/toggles.nix; o true/false é do host (hosts/<host>/services.nix).
#   3. hypr/lua/autostart.lua   → infra da sessão que PRECISA do exec-once do
#      compositor: hyprlock (a máquina sobe travada), quickshell (barra) e
#      wl-clip-persist. Não migrei p/ systemd porque o hyprlock no boot é
#      load-bearing p/ o acesso remoto (o Moonlight cai no lockscreen).
#
# POR QUE SERVIÇO E NÃO exec-once: `exec-once` NÃO reinicia se o app morrer. Serviço
# systemd reinicia. Restart=on-failure de propósito: crash volta, mas FECHAR na mão
# respeita a decisão. Com `always` você não conseguiria fechar o app — ele voltaria
# em segundos.
#
# CORREÇÃO (30/07) — este comentário dizia "(Electron sai com 0 ao fechar)" e ERA FALSO,
# pelo menos p/ o Spotify, que não é Electron e sim CEF. O que acontece de fato, MEDIDO:
# o `bin/spotify` move o processo real p/ um scope próprio
# (app-org.chromium.Chromium-<pid>.scope, FORA do cgroup da unit) e o processo que o
# systemd acompanha SAI COM 1 — sempre, mesmo quando a app subiu perfeitamente.
# Resultado com Restart=on-failure: systemd lê "falhou", reinicia em 5s, o novo launcher
# encontra a instância viva, imprime "Opening in existing browser session", MANDA A
# JANELA APARECER e sai 1 de novo. Loop infinito. Medido no journal de um dia:
# 4145 reinícios, ~200ms de CPU cada — e a janela do Spotify pulando na tela sozinha,
# que foi como o problema apareceu.
#
# Duas defesas, por isso:
#   1. successExit por app (abaixo): p/ o Spotify, sair 1 É o caminho normal — declarar
#      isso faz a unit terminar limpa em vez de "failed" e não reiniciar. O preço,
#      explícito: crash com código 1 também não volta. Aceitável porque, escapando do
#      cgroup, o systemd JÁ não supervisiona o processo real — a unit aqui é lançador,
#      não supervisor, e é honesto declarar isso.
#   2. StartLimit em TODAS as units: no máximo 3 partidas em 5min. Se algum dia isto
#      voltar a entrar em loop, a unit MORRE e fica visível em
#      `systemctl --user --failed`, em vez de rodar 4145x calada. A causa raiz do
#      estrago não foi só o código de saída — foi não haver limite nenhum: com
#      RestartSec=5 dava 2 partidas/10s, sempre abaixo do burst=5 default, então o
#      freio de fábrica nunca chegava a atuar.
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
      # unstable.* precisa CASAR com home/packages.nix, senão o autostart sobe a versão
      # quebrada da base enquanto o menu abre a boa (ver a justificativa lá).
      exec = "${pkgs.unstable.spotify}/bin/spotify";
      desc = "música";
      # Sair com 1 é o caminho NORMAL aqui (escapa p/ scope próprio; ver header).
      # Sem isto, on-failure reinicia a cada 5s e a janela reaparece sozinha.
      successExit = "1";
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
          # Freio de loop (ver header): 3 partidas em 5min e a unit desiste, FALHANDO
          # visivelmente. O default (5 em 10s) nunca atuava com RestartSec=5.
          StartLimitIntervalSec = 300;
          StartLimitBurst = 3;
        };
        Service = {
          ExecStart = app.exec;
          Restart = "on-failure";
          RestartSec = 5;
        }
        // lib.optionalAttrs (app ? successExit) { SuccessExitStatus = app.successExit; };
        Install.WantedBy = [ "graphical-session.target" ];
      }
    ) enabled;
  };
}
