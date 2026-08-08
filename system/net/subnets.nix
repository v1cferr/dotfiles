# ═══════════════════════════════════════════════════════════════════════════
# FAIXAS DA REDE DE CASA = FONTE ÚNICA (regra 11). "De casa" é uma decisão de
# SEGURANÇA — é ela que separa quem entra direto de quem precisa de senha — e
# estava escrita por extenso em três lugares diferentes.
#
# O GATILHO: com a saída do Tailscale (08/08/2026) a lista virou consumidor
# triplo — o matcher `@externo` do Caddy, o `ignoreip` da jail do fail2ban e a
# regra de firewall que substituiu o `trustedInterfaces`. Literal repetido em
# 2+ lugares é exatamente o que a regra 11 manda virar opção, e aqui o custo de
# divergir é alto: uma cópia desatualizada não dá erro de build, só passa a
# tratar como estranho alguém que devia entrar — ou pior, o contrário.
#
# ARQUIVO PRÓPRIO, mesma justificativa do ./domain.nix: os consumidores estão em
# DUAS pastas (net/ e services/), então nenhum módulo é o dono óbvio.
#
# ⚠️ ESTES VALORES ESPELHAM O ROTEADOR, que é quem realmente os define (o OpenWrt
# serve o DHCP da LAN e é o servidor WireGuard). O Nix não alcança lá: mudar a
# faixa no roteador e esquecer daqui deixa o repo mentindo em silêncio.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.net = {
    lanSubnet = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
      description = "Faixa da LAN de casa (DHCP servido pelo roteador OpenWrt).";
    };

    # SEPARADA da LAN de propósito, e não juntas numa lista só: há consumidor que
    # precisa de UMA e não da outra. O firewall que mantém o Sunshine alcançável
    # confia só nesta — o Sunshine é fechado NA LAN por decisão, e mesclar as duas
    # abriria ele pra rede de casa inteira sem ninguém perceber.
    vpnSubnet = lib.mkOption {
      type = lib.types.str;
      default = "10.10.10.0/24";
      description = "Faixa do WireGuard servido pelo ROTEADOR. É por ela que o acesso remoto entra.";
    };
  };
}
