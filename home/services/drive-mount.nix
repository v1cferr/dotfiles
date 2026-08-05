# ═══════════════════════════════════════════════════════════════════════════
# ~/Drive — a RAIZ do Google Drive montada como pasta local (rclone mount + cache
# VFS) → aparece no Dolphin como pasta normal, com bookmark em home/apps/dolphin.nix.
#
# Serve o caso real: "às vezes preciso de um arquivo que não tenho aqui mas está no
# Drive". Vê tudo na hora (Documentos, César, Mãe, SENAC…), sem baixar nada.
#
# ── POR QUE MOUNT E NÃO BISYNC (decidido em 05/08/2026) ─────────────────────
# A primeira versão daqui era `rclone bisync`. Trocado depois de LISTAR o remote e
# ver que a raiz tem ~19,6 GiB de acervo real (fotos de família, documentos):
#   • bisync baixaria os 19,6 GiB pro NVMe pra dar o mesmo acesso que o mount dá com
#     zero download;
#   • e sync PROPAGA — apagar local apagaria no Drive, inclusive pasta de família.
#     Num mount cada operação é explícita e única; não existe algoritmo reconciliando
#     duas listagens que possa concluir "o outro lado deve ficar vazio".
# O que se perde: acesso OFFLINE e edição sem rede. Trade aceito — quem precisa
# funcionar offline é o backup (restic), e esse é outro módulo.
#
# ── ISTO NÃO É BACKUP ───────────────────────────────────────────────────────
# É uma JANELA pro Drive: apagar aqui apaga lá, de verdade. O backup é o restic
# (system/services/restic.nix), e ele é a única coisa que atende a regra 6.
#
# O repo do restic mora em BACKUPS_EX-B560M-V5/ e fica EXCLUÍDO da montagem: são ~48
# GiB de blob cifrado que só poluiriam o gerenciador de arquivos, e um Delete sem
# querer ali dentro CORROMPE o backup. Pra olhar dentro do backup existe o
# `backup-browse` (restic mount), que é read-only.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.drive;
in
{
  options.my.drive = {
    local = lib.mkOption {
      type = lib.types.str;
      default = "/home/v1cferr/Drive";
      description = "Ponto de montagem. Lido também pelo bookmark do Dolphin (SSOT, regra 11).";
    };
    remote = lib.mkOption {
      type = lib.types.str;
      default = "gdrive:";
      description = "Remote do rclone. `gdrive:` = raiz do Drive; o remote vem do rclone.conf do sops.";
    };
  };

  config = lib.mkIf osConfig.my.services.drive-mount {
    systemd.user.services.drive-mount = {
      Unit = {
        Description = "Google Drive montado em ${cfg.local} (rclone mount)";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        # No login a rede costuma demorar alguns segundos. Sem isto o systemd desistiria
        # após 5 falhas rápidas (StartLimit) e a pasta ficaria vazia até um start na mão.
        StartLimitIntervalSec = 0;
      };

      Service = {
        # Suportado pelo rclone (está no `rclone mount --help`, seção systemd): a unit só
        # entra em "started" DEPOIS do mountpoint pronto. Com Type=simple o Dolphin
        # poderia abrir a pasta antes de ela existir e cachear "vazia".
        Type = "notify";

        # CÓPIA GRAVÁVEL do rclone.conf. O rclone renova o token OAuth e tenta persistir
        # o novo no arquivo de config; contra o secret do sops (0400, diretório
        # não-gravável) isso vira `Failed to save config … permission denied` — não é
        # fatal, mas é ERROR recorrente no journal escondendo erro de verdade.
        # `%t` = XDG_RUNTIME_DIR (/run/user/1000), tmpfs, 0600.
        #
        # O `--config` vai no comando e NÃO como RCLONE_CONFIG no ambiente: o
        # `programs.rclone` gera o rclone.conf do remote `faiws`, e exportar a variável
        # faria o mount da FAI procurar o remote no arquivo errado. (A doc do rclone
        # ainda avisa que unit de systemd não herda ambiente — outra razão pro flag.)
        # ⚠️ O MOUNTPOINT TEM QUE ESTAR VAZIO. O rclone recusa com "…is not empty, use
        # --allow-non-empty to mount anyway" — e `--allow-non-empty` fica FORA de
        # propósito: montar por cima de arquivo existente ESCONDE ele, e aí você tem
        # dado invisível que só reaparece quando o mount cai. Custou o primeiro start
        # (05/08/2026): a versão bisync deste módulo criava um RCLONE_TEST aqui, e o
        # arquivo órfão de 0 byte travou o mount em loop de restart.
        # Se o mount não subir, checar `ls -a ~/Drive` ANTES de suspeitar de rede.
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.local}"
          "${pkgs.coreutils}/bin/install -m600 /run/secrets/rclone_gdrive_conf %t/rclone-gdrive.conf"
        ];

        ExecStart = lib.concatStringsSep " " [
          "${pkgs.rclone}/bin/rclone --config %t/rclone-gdrive.conf mount"
          cfg.remote
          cfg.local
          # Esconde o repo do restic da montagem (ver cabeçalho): ruído no Dolphin, e um
          # Delete sem querer ali corromperia o backup.
          "--exclude BACKUPS_EX-B560M-V5/**" # sem aspas: systemd não expande glob em Exec*
          # "writes": LEITURA passa direto (streaming, NÃO acumula em disco) — só o que
          # você escreve/copia é cacheado até subir. Mesma escolha do mount da FAI.
          "--vfs-cache-mode writes"
          "--vfs-cache-max-age 6h" # evicta o cache de escrita rápido
          "--vfs-cache-max-size 2G" # teto do cache em disco (~/.cache/rclone)
          "--dir-cache-time 5m" # listagem cacheada 5min → navegar fica RÁPIDO (F5 recarrega)
          "--buffer-size 8M" # RAM de read-ahead por arquivo aberto
          "--timeout 30s" # timeout de I/O (não pendura eterno se a rede cair)
          "--contimeout 15s" # timeout de conexão
          "--log-systemd" # log vai pro journal com a prioridade certa
        ];

        # O rclone desmonta sozinho no SIGTERM; isto é a rede de segurança pro caso de
        # mount pendurado (o `-` ignora falha quando já está desmontado). Tem que ser o
        # WRAPPER setuid do NixOS — o fusermount3 do pacote não tem privilégio.
        ExecStopPost = "-/run/wrappers/bin/fusermount3 -uz ${cfg.local}";

        Restart = "on-failure";
        RestartSec = 10;
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
