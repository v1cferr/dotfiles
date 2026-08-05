# ═══════════════════════════════════════════════════════════════════════════
# BACKUP DECLARATIVO (restic) — estado do usuário → Google Drive, CIFRADO.
#
# restic cifra em repouso, deduplica e versiona. O `check` verifica integridade.
#
# PAR COM O btrbk (btrbk.nix): o snapshot local horário cobre "sobrescrevi agora há
# pouco"; ESTE cobre "o disco morreu / a casa pegou fogo". Snapshot no mesmo disco
# não é backup, e sync não é backup — apagar propaga. Só o restic é backup (regra 6).
#
# A senha é SEGREDO (sops: restic_password). Sem ela o repo é lixo cifrado.
#
# ── POR QUE SÓ O DRIVE (05/08/2026) ─────────────────────────────────────────
# O destino era o HDD Seagate (/mnt/seagate-old/restic) e saiu daqui. Não foi por
# espaço: era a ÚNICA cópia do home vivo, num Momentus 7200.4 de ~2009 com 840 mil
# load cycles (40% além do spec) e 348 erros de CRC, DENTRO da mesma máquina — some
# junto com ela num roubo ou incêndio. Uma cópia offsite ganha nos modos de falha que
# de fato acontecem. Preço aceito: restauração passa pela rede e depende da conta
# Google. Medido no 1º snapshot: 40,6 GiB lidos → 23,6 GiB no fio, 15 min.
#
# O DRIVE ESTÁ VERIFICADO: `check --read-data` relendo os 189 packs deu "no errors
# were found" em 05/08/2026. O repo do Seagate mesmo assim NÃO foi apagado, e não é
# indecisão — é HISTÓRICO: o Drive tem 1 snapshot (de hoje) e o Seagate tem 13, com a
# janela de 7d/4s/6m. Apagar agora perderia toda versão anterior a hoje, que é
# exatamente o que salva quando um arquivo corrompeu semanas atrás e ninguém viu. O
# repo é estático (nada mais escreve nele) e o disco tem 195 G livres, então guardar
# não custa. Apagar quando o Drive acumular janela equivalente.
# Sem o alvo aqui o wrapper `restic-home` deixa de existir; pra ler o repo congelado
# é o restic direto:
#   sudo restic -r /mnt/seagate-old/restic --password-file /run/secrets/restic_password snapshots
#
# ── VER O QUE ESTÁ DENTRO DO BACKUP ─────────────────────────────────────────
# O repo é blob cifrado — rclone NÃO decifra, quem decifra é o restic. Para navegar
# como pasta (um diretório por snapshot, read-only):
#   sudo restic-home-gdrive mount /mnt/backup     # Ctrl+C desmonta
# O wrapper que o módulo gera já leva RCLONE_CONFIG, a senha e o rclone no PATH.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

lib.mkIf config.my.services.restic {
  # PEGADINHA que já custou o serviço do arquivo do Arch inteiro: o módulo do nixpkgs
  # põe SÓ o ssh no PATH (`path = [ config.programs.ssh.package ]`), e o backend
  # `rclone:` do restic EXECUTA o binário rclone. Sem este mkAfter, morre na largada
  # com "rclone: executable file not found in $PATH".
  systemd.services.restic-backups-home-gdrive.path = lib.mkAfter [ pkgs.rclone ];

  services.restic.backups.home-gdrive = {
    # `rclone:<remote>:<caminho>` — o restic sobe um `rclone rcd` e fala HTTP com ele.
    # O caminho nomeia a MÁQUINA (placa EX-B560M-V5) pra conviver com outros backups lá.
    repository = "rclone:gdrive:BACKUPS_EX-B560M-V5/HOME";

    passwordFile = config.sops.secrets.restic_password.path;

    # rclone.conf com o token OAuth = SEGREDO (regra 12). NUNCA a opção `rcloneConfig`
    # (attrset): ela vaza o token pro /nix/store, que é world-readable.
    rcloneConfigFile = config.sops.secrets.rclone_gdrive_conf.path;

    initialize = true; # cria o repo no 1º backup

    paths = [ "/home/v1cferr" ];

    # exclui o regenerável (cache/build/lixo). O `storage` do Zen (dados de site)
    # NÃO é cache → fica; só o cache2 (http cache do Firefox/Zen) sai.
    exclude = [
      # MOUNT DE OUTRA MÁQUINA — não é "regenerável", é ALHEIO. Sem esta linha o backup
      # FALHAVA de forma INTERMITENTE (05/08/2026): `error: lstat
      # /home/v1cferr/FAI-workstation: permission denied` → restic sai 3, e como o
      # `backup` é o 1º de três ExecStart, o `unlock` e o `forget --prune` NÃO rodavam —
      # a retenção silenciosamente não se aplicava. A causa é de permissão, não de
      # config: o mount é FUSE do USUÁRIO (rclone SFTP, home/services/fai-workstation-mount.nix)
      # e o backup roda como ROOT, que não entra em FUSE alheio. Intermitente porque só
      # existe quando a VPN da FAI está de pé — o run das 06:44 passou, o das 14:55 não.
      # `--one-file-system` não salva: ele impede DESCER no mount, mas o restic ainda
      # dá lstat no ponto de montagem. Backup de máquina remota nunca deveria entrar aqui.
      "/home/v1cferr/FAI-workstation"

      "/home/v1cferr/.cache"
      "/home/v1cferr/.local/share/Trash"
      # ── Volumosos e RE-OBTENÍVEIS (não faz sentido cifrar/guardar) ──
      "/home/v1cferr/Downloads" # transiente
      "/home/v1cferr/Games" # jogos (PS3 etc.) — re-baixáveis das fontes
      "/home/v1cferr/.local/share/bottles" # prefixos Wine (~154G): jogos re-instaláveis. NOTA: saves de jogo vivem aqui dentro — se algum for insubstituível, faça backup à parte.
      "/home/v1cferr/.local/share/Steam" # biblioteca Steam, se houver (re-baixável)
      "**/node_modules"
      "**/.direnv"
      "**/target" # builds Rust
      "**/__pycache__"
      "**/.venv"
      "**/Cache"
      "**/Cache_Data"
      "**/CachedData"
      "**/Code Cache"
      "**/GPUCache"
      "**/ShaderCache"
      "**/cache2" # http cache do Firefox/Zen (mantém o 'storage')
      "**/startupCache"
    ];

    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true; # roda no boot se perdeu o horário
      RandomizedDelaySec = "30min";
    };

    extraBackupArgs = [
      # A opção que decide a VIABILIDADE (não é otimização): no Drive o custo é por
      # CHAMADA de API, não por byte, e são 255 MIL arquivos aqui. Em objetos de 128 MiB
      # (o máximo do restic) isso vira alguns milhares de objetos.
      "--pack-size=128"
      "--one-file-system" # não atravessa pra outro FS se aparecer mount aninhado
      "--exclude-caches" # pula diretório com CACHEDIR.TAG (padrão freedesktop)
    ];

    # Progresso 1x/min no journal. No default (1 fps) um upload de 15 min viraria
    # milhares de linhas.
    progressFps = 0.0167;

    # retenção: poda automática após cada backup
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
      # Poda em repo remoto REEMPACOTA: baixa packs parcialmente usados e sobe de volta.
      # Sem teto, um prune ruim viraria horas de tráfego. O que não couber hoje é podado
      # na próxima execução.
      "--max-repack-size=2G"
    ];

    # `--read-data-subset` fica FORA de propósito: reler = BAIXAR. 10% por dia de um
    # repo de ~24 GiB seria ~2,4 GiB de download TODO DIA, pra sempre. Aqui o check é só
    # de ESTRUTURA (índices e árvores), que é metadado e sai barato. A leitura integral
    # dos dados é MANUAL e deliberada:
    #   sudo restic-home-gdrive check --read-data
    checkOpts = [ ];
  };
}
