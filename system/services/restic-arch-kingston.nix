# ═══════════════════════════════════════════════════════════════════════════
# ARQUIVO MORTO do Arch antigo (/mnt/kingston-arch) → Google Drive, CIFRADO.
#
# Backup DE MUDANÇA, não de rotina: o Kingston (NVMe) vai ser formatado pra virar
# o daily driver NixOS e o SanDisk vira Windows.
#
# ESCOPO: só o /home, e sem o regenerável. O resto do rootfs (~215 G de /usr, /var,
# cache do pacman) não tem nada insubstituível — os dotfiles do Arch estão no GitHub.
# Com as exclusões abaixo mais uma limpeza manual (jul/2026) que tirou 190 G de
# biblioteca Jellyfin DUPLICADA (byte a byte igual ao /srv/media do SanDisk) e de
# jogos re-baixáveis, o home filtrado deu 50 G. Sobrou acervo puro.
#
# POR QUE NUVEM, se 50 G cabem folgado no Seagate: a razão NÃO é capacidade, é ser
# OFFSITE. Toda cópia local desta máquina está no caminho da reorganização — o
# SanDisk vira Windows 11 e o Kingston é o disco que este backup existe pra esvaziar.
# O Drive é a única perna que atravessa isso inteiro. Uma cópia extra no Seagate é
# barata e BOA (3-2-1), mas é complemento, não substituto.
#
# ISTO É ACERVO, NÃO INSUMO DA MIGRAÇÃO. O home que vai virar daily driver no Kingston
# é o que já roda no SanDisk hoje, copiado DISCO A DISCO (minutos a 500 MB/s). Este
# repo aqui é o Arch velho, pra garimpar depois — nunca entra no caminho crítico.
#
# Roda UMA vez, À MÃO: `timerConfig = null` ⇒ o módulo não cria timer nenhum
# (nixpkgs filtra por `timerConfig != null`). Dispara com:
#     sudo systemctl start restic-backups-arch-kingston
#
# POR QUE restic e não `rclone copy`/`bisync`:
#   • Centenas de milhares de arquivos na API do Drive levariam SEMANAS — o custo lá
#     é por CHAMADA, não por byte. O restic empacota em blobs de 128 MiB ⇒ poucos
#     milhares de objetos. É isso que torna a subida viável.
#   • O Drive não guarda dono/permissão/symlink/hardlink. Um rootfs copiado
#     arquivo-a-arquivo não volta como sistema. O restic preserva metadata POSIX.
#   • Sobem /etc/shadow, chaves SSH e tokens de sessão: cifrar não é opcional.
#   • `restic-arch-kingston check --read-data` PROVA que dá pra restaurar ANTES
#     de formatar o disco. Com tar na nuvem você reza.
#   • Retomável: uma queda no meio não recomeça do zero.
#   • Compressão: medido em 01/08/2026 — 44,6 GiB lidos viraram 23,7 GB no fio.
#
# DOIS DESTINOS, mesma fonte e mesma senha (repos intercambiáveis na restauração):
#   arch-kingston        → Google Drive  (perna OFFSITE)
#   arch-kingston-local  → Seagate       (perna RÁPIDA, restaura sem depender da net)
# Isso é o 3-2-1: duas mídias, uma fora de casa. O Seagate é um Momentus 7200.4 de
# ~2009 com 840 mil load cycles (40% além do spec) e 348 erros de CRC no barramento
# — sem setor realocado, mas NÃO é candidato a cópia única. Daí ser complemento.
#
# PEGADINHA (custou o serviço inteiro): o módulo do nixpkgs põe SÓ o ssh no PATH
# (`path = [ config.programs.ssh.package ]`), e o backend `rclone:` do restic
# EXECUTA o binário rclone. Sem o `mkAfter` abaixo, morre na largada com
# "rclone: executable file not found in $PATH". O wrapper `restic-arch-kingston`
# herda o mesmo PATH, então o mkAfter conserta os dois de uma vez.
#
# CICLO DE VIDA: isto é temporário. Depois do check --read-data passar e o Kingston
# estar formatado, desligue em toggles.nix e apague este arquivo. O repo no Drive
# sobrevive sozinho — só a senha (Bitwarden) é necessária pra restaurar.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # SSOT dos dois destinos (regra 11): fonte, exclusões e flags NÃO podem existir
  # duplicadas — duas listas divergem em silêncio e aí os repos param de ser
  # intercambiáveis, que é justamente a propriedade que os torna redundância.
  comum = {
    # Senha PRÓPRIA, separada do repo do home vivo (Seagate/restic.nix): repos
    # independentes não compartilham segredo. Mas os DOIS destinos daqui usam a
    # MESMA, de propósito — é o que deixa restaurar de qualquer um dos dois.
    passwordFile = config.sops.secrets.restic_password_arch_kingston.path;

    initialize = true; # cria o repo na primeira execução
    timerConfig = null; # SEM timer — disparo manual (ver cabeçalho)

    paths = [ "/mnt/kingston-arch/home" ]; # só o home (ver ESCOPO no cabeçalho)

    # Tudo aqui é RE-OBTENÍVEL da fonte ou puro cache. Os tamanhos são de jul/2026 e
    # existem pra justificar a linha, não pra serem exatos. Mesma filosofia (e os
    # mesmos padrões `**/`) do restic.nix, pra as duas listas não divergirem.
    exclude = [
      # ── Cache e lixeira ─────────────────────────────────────────────────────
      "/mnt/kingston-arch/home/v1cferr/.cache" # 58 G
      "/mnt/kingston-arch/home/v1cferr/.local/share/Trash" # 37 G

      # ── Jogos e prefixos Wine: re-instaláveis das fontes ─────────────────────
      # ATENÇÃO: saves de jogo vivem dentro do bottles. Se algum for insubstituível,
      # tire de lá ANTES — daqui ele não sobe (mesma pegadinha anotada no restic.nix).
      "/mnt/kingston-arch/home/v1cferr/.local/share/bottles" # 64 G
      "/mnt/kingston-arch/home/v1cferr/.local/share/Steam" # 9 G
      "/mnt/kingston-arch/home/v1cferr/.local/share/lutris" # 3 G
      "/mnt/kingston-arch/home/v1cferr/.local/share/umu" # 2,8 G
      "/mnt/kingston-arch/home/v1cferr/Games" # 3,1 G (PS3 etc.)

      # ── Toolchains e stores de pacote: um `install` reconstrói ───────────────
      "/mnt/kingston-arch/home/v1cferr/.npm" # 7 G
      "/mnt/kingston-arch/home/v1cferr/.local/share/pnpm" # 5,4 G
      "/mnt/kingston-arch/home/v1cferr/.vscode-server" # 4,3 G (binários do VS Code remoto)
      "/mnt/kingston-arch/home/v1cferr/.cargo" # 4 G
      "/mnt/kingston-arch/home/v1cferr/.gradle" # 3,2 G
      "/mnt/kingston-arch/home/v1cferr/miniconda" # 2,8 G
      "/mnt/kingston-arch/home/v1cferr/go" # 1,9 G
      "/mnt/kingston-arch/home/v1cferr/.rustup" # 1,7 G
      "/mnt/kingston-arch/home/v1cferr/.pub-cache" # 1,2 G
      "/mnt/kingston-arch/home/v1cferr/.bun"
      "/mnt/kingston-arch/home/v1cferr/.nuget"
      "/mnt/kingston-arch/home/v1cferr/miniconda.sh" # instalador de 150 M

      # ── Artefatos de build, por projeto (~12 G somados) ──────────────────────
      "**/node_modules"
      "**/.direnv"
      "**/target" # builds Rust
      "**/__pycache__"
      "**/.venv"

      # ── Cache de aplicativo. O `storage` do Zen (dados de site) NÃO é cache e
      #    fica; só o cache2 (http cache) sai — idem restic.nix.
      "**/Cache"
      "**/Cache_Data"
      "**/CachedData"
      "**/Code Cache"
      "**/GPUCache"
      "**/ShaderCache"
      "**/cache2"
      "**/startupCache"
    ];

    extraBackupArgs = [
      # 128 MiB por pack (máximo do restic). É A opção que decide a viabilidade:
      # junta centenas de milhares de arquivos em poucos milhares de objetos no Drive.
      "--pack-size=128"
      "--one-file-system" # não atravessa pra outro FS se aparecer mount aninhado
      "--exclude-caches" # pula diretório marcado com CACHEDIR.TAG (padrão freedesktop)
    ];

    # Progresso 1x/min no journal. No default (1 fps) seriam milhares de linhas.
    progressFps = 0.0167;

    pruneOpts = [ ]; # arquivo morto: um snapshot só, nada pra podar
    runCheck = false; # verificação é MANUAL e deliberada (ver cabeçalho)
  };
in
lib.mkIf config.my.services.arch-kingston-archive {
  # O backend rclone é um binário externo; o módulo só põe ssh no PATH (ver cabeçalho).
  # Só o destino do Drive precisa — o do Seagate escreve direto no filesystem.
  systemd.services.restic-backups-arch-kingston.path = lib.mkAfter [ pkgs.rclone ];

  # SEGURANÇA: sem o Kingston montado, /mnt/kingston-arch é um diretório VAZIO na raiz
  # do SanDisk — o backup "daria certo" e arquivaria nada. Mesmo padrão do restic.nix.
  # O destino local exige TAMBÉM o Seagate, senão o repo iria parar na raiz do SanDisk.
  systemd.services.restic-backups-arch-kingston.unitConfig.RequiresMountsFor = "/mnt/kingston-arch";
  systemd.services.restic-backups-arch-kingston-local.unitConfig.RequiresMountsFor =
    "/mnt/kingston-arch /mnt/seagate-old";

  # ── OFFSITE: Google Drive ───────────────────────────────────────────────────
  services.restic.backups.arch-kingston = comum // {
    # `rclone:<remote>:<caminho>` — o restic sobe um `rclone rcd` e fala HTTP com ele.
    # O caminho nomeia a MÁQUINA de origem (placa EX-B560M-V5) e o DISCO, pra quando
    # existirem outros arquivos mortos lá dentro e ninguém lembrar de onde vieram.
    repository = "rclone:gdrive:BACKUPS_EX-B560M-V5/KINGSTON";

    # rclone.conf com o token OAuth = SEGREDO (regra 12) → vira RCLONE_CONFIG no serviço.
    # NUNCA usar a opção `rcloneConfig` (attrset): ela vaza o token pro /nix/store.
    rcloneConfigFile = config.sops.secrets.rclone_gdrive_conf.path;
  };

  # ── LOCAL: Seagate ──────────────────────────────────────────────────────────
  # Repo SEPARADO do /mnt/seagate-old/restic (que é o home vivo): mesmo disco, mas
  # misturar acervo morto com rotação diária faria a política de retenção de um
  # valer pro outro. Aqui não há prune nenhum — o snapshot é pra durar.
  services.restic.backups.arch-kingston-local = comum // {
    repository = "/mnt/seagate-old/restic-arch-kingston";
  };
}
