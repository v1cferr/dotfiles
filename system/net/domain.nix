# ═══════════════════════════════════════════════════════════════════════════
# DOMÍNIO PÚBLICO = FONTE ÚNICA (regra 11). Todo serviço exposto vive sob um
# subdomínio deste nome.
#
# Antes desta opção o literal `v1cferr.dev` aparecia uma vez só, no
# `services.cloudflare-dyndns.domains` de ./network.nix — e um literal solitário
# não justifica opção. Com o Caddy de volta (system/services/caddy.nix) os
# consumidores viraram quatro: o DDNS, o endereço do site block, os matchers de
# acesso e o filtro do fail2ban. É exatamente o gatilho da regra 11 — valor
# repetido em 2+ lugares vira `my.<domínio>.<coisa>` e ninguém mais guarda
# literal.
#
# POR QUE ARQUIVO PRÓPRIO, e não dentro do módulo que consome (como `my.fonts.ui`
# mora em hardware/fonts.nix e `my.monitors` em desktop/monitors.nix): aqui os
# consumidores estão em DUAS pastas (net/ e services/), então nenhum módulo é o
# dono óbvio. Fica em net/ porque domínio é fato de rede.
#
# COM `default`, ao contrário de `my.monitors`: conector de vídeo é fato de
# HARDWARE, e default ali seria a mentira que só aparece no host nº 2. Domínio é
# fato de IDENTIDADE — mesmo critério que dá default a `my.fonts.ui`.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.net.domain = lib.mkOption {
    type = lib.types.str;
    default = "v1cferr.dev";
    description = "Domínio público sob o qual os serviços são expostos (SSOT, regra 11). Lido pelo DDNS, pelo Caddy e pelas jails do fail2ban.";
  };
}
