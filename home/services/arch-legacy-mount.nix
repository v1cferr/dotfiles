# ═══════════════════════════════════════════════════════════════════════════
# /mnt/arch-antigo — o acervo do Arch antigo montado PERMANENTEMENTE (restic mount).
#
# Era o alias `arch-browse`, rodado à mão e vivo só enquanto o terminal ficasse aberto.
# O sintoma que matou o alias (11/08/2026): abrir o bookmark do Dolphin e ver pasta
# VAZIA. Não havia defeito nenhum — segredos legíveis, repo respondendo, mount subindo
# em ~20 s quando pedido. O defeito era o DESENHO: automação sem dono declarado (regra
# 15) que dependia de eu lembrar do comando e de nunca fechar aquele terminal.
#
# ── POR QUE UNIT DO USUÁRIO, E NÃO DO SISTEMA ───────────────────────────────
# Mount FUSE é privado de quem montou: `sudo restic mount` gera pasta que o Dolphin não
# abre (foi o defeito da 1ª versão do alias). O mountpoint em si é criado por root via
# tmpfiles, em system/services/arch-legacy.nix, que também guarda a SSOT do caminho.
#
# ── O PREÇO DE DEIXAR DE PÉ (medido em 11/08/2026) ──────────────────────────
# ~195 MiB de RSS residentes: 115 MiB do restic (índice do repo em memória, 44,6 GiB de
# snapshot) + 79 MiB do `rclone serve restic`. Em REDE, parado, é ZERO: o restic não
# faz polling, só lê quando alguém lê. O comentário do bookmark em home/apps/dolphin.nix
# dizia que um mount permanente seria "conexão aberta e lock no repo por nada" — a
# primeira metade era verdade e virou uma escolha consciente; a segunda o `--no-lock`
# resolve (abaixo).
#
# ⚠️ SE A REDE CAIR, leitura pendura até o timeout do rclone e o mount pode ficar
# zumbi ("Transport endpoint is not connected"). O remédio é `systemctl --user restart
# arch-antigo-mount` — o ExecStopPost desmonta o resto à força antes de subir de novo.
# Mesma exposição do ~/Drive, que roda assim desde 05/08/2026 sem incidente.
# ═══════════════════════════════════════════════════════════════════════════
{
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = osConfig.my.archAntigo;

  # READINESS. O `restic mount` NÃO fala sd_notify (conferido: nada de "notify" no
  # `restic mount --help` da 0.18.1), então não dá pra copiar o `Type = "notify"` que o
  # ~/Drive usa — e com Type=simple o systemd daria a unit por pronta no instante em que
  # o processo nasce, ou seja, ANTES do mountpoint existir. Aí o Dolphin abriria a pasta
  # vazia e cacharia isso: exatamente o sintoma que este módulo veio resolver.
  # ExecStartPost bloqueia o "started" até o mount aparecer de verdade.
  #
  # writeShellApplication e não `.sh` solto nem `sh -c` de duas linhas (regra 7): a
  # lógica mora no build, e assim passa pelo shellcheck.
  aguardaMount = pkgs.writeShellApplication {
    name = "arch-antigo-aguarda-mount";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
    # 120 tentativas de 1 s. Cold cache (índice ainda não baixado do Drive) levou ~20 s
    # na medição; a folga é pra rede ruim, e o teto existe pra `Restart=on-failure` poder
    # tentar de novo em vez de deixar a unit "activating" pra sempre.
    text = ''
      for _ in $(seq 1 120); do
        mountpoint -q ${cfg.local} && exit 0
        sleep 1
      done
      echo "mountpoint ${cfg.local} não apareceu em 120 s" >&2
      exit 1
    '';
  };
in
lib.mkIf osConfig.my.services.arch-antigo-mount {
  systemd.user.services.arch-antigo-mount = {
    Unit = {
      Description = "Acervo do Arch antigo montado em ${cfg.local} (restic mount, read-only)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # No login a rede costuma demorar alguns segundos. Sem isto o systemd desistiria
      # após 5 falhas rápidas (StartLimit) e a pasta ficaria vazia até um start na mão.
      StartLimitIntervalSec = 0;
    };

    Service = {
      Type = "simple"; # sd_notify não existe aqui — ver `aguardaMount` acima

      # CÓPIA GRAVÁVEL do rclone.conf, mesmo padrão do ~/Drive e do serviço de backup. O
      # rclone renova o token OAuth e tenta persistir o novo POR CIMA do arquivo de
      # config; contra o segredo do sops (0400, diretório não-gravável) isso vira
      # `Failed to save config … permission denied`. Não é fatal — mas num serviço 24/7
      # seria ERROR recorrente no journal escondendo erro de verdade.
      # Arquivo PRÓPRIO (`-arch-antigo`) e não o `%t/rclone-gdrive.conf` do ~/Drive: duas
      # units reescrevendo a mesma cópia é o mesmo pisão que o backup dava no segredo
      # (07/08/2026, ver restic.nix). `%t` = XDG_RUNTIME_DIR (/run/user/1000), tmpfs.
      ExecStartPre = "${pkgs.coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-arch-antigo.conf";

      # O restic não tem flag pra apontar o rclone.conf: só o backend lê, e ele lê do
      # AMBIENTE. Aqui é seguro (o de dentro da unit, não o da sessão) — o alerta do
      # drive-mount.nix é sobre exportar RCLONE_CONFIG por fora e fazer o mount da FAI
      # procurar o remote `faiws` no arquivo errado.
      Environment = [ "RCLONE_CONFIG=%t/rclone-arch-antigo.conf" ];

      ExecStart = lib.concatStringsSep " " [
        "${pkgs.restic}/bin/restic"
        "-r ${cfg.repo}"
        "--password-file /run/secrets/restic_password_arch_kingston"
        # PEGADINHA que já custou o serviço de backup inteiro: o backend `rclone:` EXECUTA
        # o binário rclone, e unit de systemd não herda o PATH da sessão. Lá o remédio foi
        # `path = [ pkgs.rclone ]`; aqui o store path vai PINADO no `-o`, que não depende
        # de PATH nenhum. Os args default (`serve restic --stdio`) continuam valendo.
        "-o rclone.program=${pkgs.rclone}/bin/rclone"
        "mount ${cfg.local}"
        # SEM LOCK, e isto é decisão medida, não economia. Todo `restic mount` cria um lock
        # não-exclusivo e o renova a cada ~5 min; mount que morre sem sair limpo o deixa
        # PRESO. Em 11/08/2026 o repo tinha 3 locks: um do mount vivo e dois restos de
        # `arch-browse` de 05/08 e 08/08 — um mount permanente só ia piorar isso, e ainda
        # escreveria no repo offsite a cada 5 min pra sempre.
        # O que o lock protege é leitura concorrente com poda; este repo é ESTÁTICO e
        # NENHUMA rotina o poda (o `forget --prune` automático só olha o repo HOME). Se um
        # dia algo passar a escrever aqui, esta linha é a primeira a sair.
        "--no-lock"
      ];

      ExecStartPost = lib.getExe aguardaMount;

      # 120 s de espera + a subida do restic não cabem nos 90 s default, e estourar o
      # TimeoutStartSec MATA a unit no meio da espera.
      TimeoutStartSec = 180;

      # Rede de segurança pro mount pendurado (o `-` ignora falha quando já está
      # desmontado): sem isto sobra o "Transport endpoint is not connected", e aí o mount
      # seguinte não sobe porque o mountpoint está ocupado por um cadáver. Tem que ser o
      # WRAPPER setuid do NixOS — o fusermount3 do pacote não tem privilégio.
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

      Restart = "on-failure";
      RestartSec = 10;
    };

    Install.WantedBy = [ "default.target" ];
  };
}
