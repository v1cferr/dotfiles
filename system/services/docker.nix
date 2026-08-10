# ═══════════════════════════════════════════════════════════════════════════
# DOCKER — política de PODA automática. Este módulo não liga a engine.
#
# QUEM LIGA A ENGINE são os stacks (./duo.nix, ./grad-radar.nix), cada um com o
# seu `virtualisation.docker.enable = true`. A poda é preocupação da MÁQUINA, não
# de um stack: qualquer um dos dois pode ter sido o que subiu o daemon, e o lixo
# que se acumula é do daemon, não deles. Por isso o `mkIf` olha pro estado da
# engine em vez de um toggle próprio — ligou docker por qualquer caminho, ganha
# poda; nenhum stack ligado, este módulo não faz nada.
#
# O PROBLEMA MEDIDO (10/08/2026), que é o único crescimento SEM TETO da máquina:
#
#     Build Cache   287 entradas   11.35 GB   RECLAIMABLE: 8.545 GB
#
# Nada podava isso — não há timer, não há política, e o cache só cresce. Compare
# com os vizinhos, que TÊM teto: journald está em `SystemMaxUse=2G`, coredump é
# vacuado pelo systemd, o btrbk tem `snapshot_preserve`, o nix tem `gc` semanal.
# O Docker era o único sem nada.
# E o ./grad-radar.nix PIOROU isso no mesmo dia em que entrou: ele roda
# `docker compose build` no ExecStartPre, ou seja, a CADA BOOT. Sem poda, o cache
# ganha camada nova toda vez que a máquina liga.
#
# ── AS DUAS OPÇÕES QUE PARECEM "MAIS COMPLETAS" E DESTROEM DADO ─────────────
# As duas falham na MESMA janela: o stack PARADO na hora da poda. Nenhuma das
# duas dá erro — elas apagam com sucesso o que não deviam.
#
# ⚠️⚠️ `autoPrune.allVolumes.enable` — NUNCA. Ela poda volume NOMEADO, não só
# anônimo, e é onde moram os bancos: `duo_duo-db-data`, `duo_duo-data`,
# `grad-radar_db_data` (conferido com `docker volume ls`). Com o compose derrubado
# — reboot, `down` manual, ConditionPathExists falhando — a poda semanal apaga o
# Postgres dos dois projetos. O nome da opção sugere "limpar mais"; o efeito é
# perda de dado silenciosa. O default (anônimo só) é o certo e fica como está.
#
# ⚠️ `flags = [ "--all" ]` — recusado, apesar de ser o que a maioria dos configs
# públicos usa. O `--all` remove imagem COM TAG que não esteja em uso por um
# container RODANDO. As imagens locais (duo-web, duo-api, duo-daemon,
# grad-radar-backend) não vêm de registry: some = rebuild. No grad-radar o rebuild
# inclui `pnpm install` DENTRO do container — é por isso que a unit tem
# `TimeoutStartSec = 1800`. Trocar minutos de boot por alguns GB não paga, ainda
# mais porque o `prune` sem `--all` já leva o que interessa aqui: o build cache
# pendurado, imagem dangling, container parado e rede órfã.
#
# CONFERIR o que a poda vai levar ANTES de confiar nela:
#   docker system df -v    # o peso item a item (imagem, container, cache)
#   docker system prune    # SEM o -f: lista as categorias e pede y/N — responder
#                          # N é a prévia. NÃO existe `--dry-run` (conferido no
#                          # --help do Docker 29.6.2); a confirmação é o que há.
# ═══════════════════════════════════════════════════════════════════════════
{ config, lib, ... }:

lib.mkIf config.virtualisation.docker.enable {
  virtualisation.docker.autoPrune = {
    enable = true;

    # `weekly` do systemd = Mon 00:00, que é EXATAMENTE o horário do nix-gc
    # (system/core/core.nix). Duas faxinas pesadas de I/O no mesmo minuto, na
    # mesma NVMe, sem ganho nenhum em juntá-las. 04:30 cai depois do restic
    # (03:00 + até 30 min de atraso aleatório) e do nix-optimise (03:45), então
    # a janela da madrugada fica em fila e não em disputa.
    dates = "Mon 04:30";

    # `persistent` já vem `true` do módulo, e aqui isso NÃO é detalhe: esta
    # máquina passa noites desligada, então um timer semanal de madrugada sem
    # persistência simplesmente nunca rodaria. Não redeclarado de propósito —
    # o default já está certo.
  };
}
