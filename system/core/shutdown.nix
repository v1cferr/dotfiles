# ═══════════════════════════════════════════════════════════════════════════
# DESLIGAMENTO — quanto tempo o systemd espera uma unit parar antes do SIGKILL.
#
# SINTOMA: "A stop job is running…" e o desligamento levando um minuto e meio.
# MEDIDO em 09/08/2026, nos 10 últimos boots: 90,3 / 90,4 / 90,5 / 90,6 s…
# Número redondo demais pra ser trabalho real — isso não é o sistema fazendo
# algo, é TIMEOUT batendo. E o timeout era o default do systemd: 90 s.
#
# CULPADO ÚNICO, e ele é do lado do USUÁRIO: o VS Code. Ele roda num scope da
# sessão (`app-code-<pid>.scope`, criado pelo GLib ao lançar o `.desktop`) e
# não responde ao SIGTERM — todo shutdown fecha igual, `app-code-*.scope:
# Stopping timed out. Killing.` + SIGKILL. Antes do VS Code, o mesmo padrão
# aparecia com o Chromium; é comportamento de Electron, não desta máquina.
# Todo o RESTO — docker, jellyfin, rede, unmounts, swap — para em menos de 2 s.
# Ou seja: não havia nada a otimizar, só espera por um processo que nunca ia
# responder.
#
# O QUE ESTA MUDANÇA NÃO FAZ: ela não passa a matar nada que antes morria de
# morte natural. O SIGKILL já acontecia — 90 s depois. Quem salva estado no
# SIGTERM (pipewire, dropbox, rclone, os daemons todos) leva menos de 1 s e
# continua salvando; quem ignora o sinal só deixa de cobrar a espera.
#
# POR QUE 5 s no usuário e 30 s no sistema — os dois lados têm inquilinos
# diferentes, e um valor só serviria mal aos dois:
#   • USUÁRIO são apps de desktop. Quem ia salvar já salvou; o que sobra é
#     Electron pendurado. 5 s é folga generosa pra um SIGTERM honesto.
#   • SISTEMA tem `docker compose down` no ExecStop (duo, grad-radar), e o
#     `down` dá 10 s de carência a CADA container antes de matar. Um teto
#     apertado aqui SIGKILLaria o Postgres desses stacks no meio do down — não
#     corrompe, mas volta fazendo recovery de WAL no boot seguinte, e o preço
#     aparece longe da causa. 30 s cobre o down com folga e ainda é 3× mais
#     rápido que o default.
#
# ⚠️ Isto é DEFAULT, não teto: unit com `TimeoutStopSec` PRÓPRIO ignora tudo
# aqui — hoje qbittorrent (30 min), jellyfin (15 s), caddy (5 s),
# hyprpolkitagent (5 s) e `user@.service` (2 min, do upstream). Se um dia o
# desligamento voltar a demorar, procurar primeiro quem declarou o próprio
# valor: `systemctl show <unit> -p TimeoutStopUSec`.
#
# ⚠️ OS DOIS LADOS TÊM APIS DIFERENTES, e a assimetria é armadilha de verdade:
# `systemd.extraConfig` FOI REMOVIDA (26.05 manda usar `systemd.settings.Manager`,
# freeform), mas `systemd.user.extraConfig` continua sendo a única forma do lado do
# usuário — `systemd.user.settings` NÃO existe (conferido nas `options`). E o modo
# como isso falha é o pior possível: escrevendo na opção removida, o `nix eval` do
# `system.conf` gerado passa e sai SEM a linha. Nada avisa. Por isso a validação
# aqui não é "buildou?", é LER o arquivo gerado:
#   nix eval --raw .#nixosConfigurations.nixos-kingston.config.environment.etc.\"systemd/system.conf\".text
#
# COMO CONFERIR o efeito, sem cronômetro na mão — os dois carimbos do journal:
#   journalctl -b -1 -o short-precise | grep -E "Stopping User Manager|Journal stopped"
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  # Sistema: 30 s (e não menos) por causa do `docker compose down` — ver o bloco.
  systemd.settings.Manager.DefaultTimeoutStopSec = "30s";

  # Sessão do usuário: 5 s. É aqui que moravam os 90 s (o scope do VS Code).
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=5s
  '';
}
