# ═══════════════════════════════════════════════════════════════════════════
# INTERFACE dos serviços opcionais — a LISTA de chaves que existem. Aqui NÃO se
# liga nada: o valor (true/false) é decisão de CADA MÁQUINA e mora no painel do
# host, hosts/<host>/services.nix.
#
# Por que a declaração fica aqui e não em cada módulo de serviço (04/08/2026):
# `osConfig` só enxerga o namespace do NixOS, então uma opção lida por módulo de
# home (dropbox, discord-rpc, cs2-backup) TEM que ser declarada por um módulo de
# SISTEMA. Distribuir as declarações deixaria três órfãs precisando de um arquivo
# central de qualquer jeito — pior que uma lista só, que ainda serve de contrato
# legível do que este repo sabe ligar e desligar.
#
# Cada serviço lê seu flag via config.my.services.<nome> (sistema) ou
# osConfig.my.services.<nome> (home-manager).
#
# ESSENCIAIS ficam FORA de propósito (tailscale, mouse/logid, desktop hypr*, keyring,
# earlyoom, fail2ban, fwupd) — não dá pra desligar por engano. VPN é sob-demanda (fora).
#
# Chave nova aqui SEM valor no host nasce `false` (mkEnableOption) — serviço novo que
# não sobe é o sintoma; o remédio é a linha no painel do host.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.services = lib.genAttrs [
    "jellyfin"
    "ollama"
    "duo"
    "sunshine"
    "qbittorrent"
    "tor"
    "restic"
    "btrbk"
    "cloudflare-ddns"
    "dropbox"
    "discord-rpc"
    "cs2-backup"
  ] (n: lib.mkEnableOption n);
}
