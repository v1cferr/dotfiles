# ═══════════════════════════════════════════════════════════════════════════
# INGRESS = FONTE ÚNICA de quem é exposto e até onde (regra 11). Cada serviço
# que ganha um subdomínio se declara AQUI, e o Caddyfile é GERADO daqui —
# nunca o contrário.
#
# O PROBLEMA QUE ISTO RESOLVE: antes, o alcance de cada serviço era implícito e
# espalhado pelo Caddyfile. O `duo` e o `ai` tinham `respond @externo 403`
# escrito à mão; o `jellyfin` e o `torrent` simplesmente NÃO tinham, e só o
# comentário ao lado dizia que era de propósito. Para saber o que estava exposto
# era preciso ler 60 linhas de Caddyfile e reparar numa AUSÊNCIA — que é o pior
# jeito de codificar uma decisão de segurança, porque esquecer de escrever vira
# "exposto" em silêncio. Com `expose`, o default é `lan`: esquecer FECHA.
#
# COMO ALTERNAR: uma palavra no painel do host (hosts/*/services.nix).
#   expose = "lan"    → só rede de casa (LAN + WireGuard do roteador)
#   expose = "public" → alcançável de fora, sujeito ao `auth` declarado
#
# `public` FUNCIONA de verdade: o roteador tem IP público na pppoe-wan e encaminha
# 80/443 pra cá (houve um susto de CGNAT em 07/08/2026 que se provou falso — ver
# docs/history/2026/08-august.md). Um serviço marcado `public` é alcançável da internet HOJE.
#
# A opção mora em net/ e não dentro do caddy.nix porque descreve ALCANCE DE REDE, não
# detalhe do proxy — hoje o Caddy é o único consumidor, mas a decisão não é dele.
# ═══════════════════════════════════════════════════════════════════════════
{ lib, ... }:

{
  options.my.ingress = lib.mkOption {
    default = { };
    description = "Serviços com subdomínio próprio sob `my.net.domain`. Gera os vhosts do Caddy (e, no futuro, o ingress do túnel).";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          upstream = lib.mkOption {
            type = lib.types.port;
            description = "Porta em 127.0.0.1 que atende tudo o que não casar em `routes`.";
          };

          # Default FECHADO de propósito: ver o bloco do cabeçalho. Esquecer de
          # declarar não pode significar "abre pra internet".
          expose = lib.mkOption {
            type = lib.types.enum [
              "lan"
              "public"
            ];
            default = "lan";
            description = "Alcance: `lan` (casa + WireGuard) ou `public` (internet). Default fechado — omitir NUNCA expõe.";
          };

          # user -> nome da variável de ambiente que carrega o hash bcrypt (o
          # valor vem do sops via caddy.env; regra 12: nada de segredo na store).
          # Só se aplica a quem vem de FORA — na rede de casa abre direto.
          auth = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = {
              v1cferr = "CADDY_POS_HASH_V1CFERR";
            };
            description = "basic_auth exigido de quem vem de fora: usuário → variável do .env com o hash bcrypt.";
          };

          # Prefixo de path -> porta. Avaliado ANTES do `upstream`, na ordem em
          # que o Caddy resolve `handle` (mais específico primeiro).
          routes = lib.mkOption {
            type = lib.types.attrsOf lib.types.port;
            default = { };
            example = {
              "/api/*" = 8006;
            };
            description = "Rotas por prefixo que vão pra uma porta diferente do `upstream`.";
          };

          proxyConfig = lib.mkOption {
            type = lib.types.lines;
            default = "";
            example = "flush_interval -1";
            description = "Diretivas extras DENTRO do `reverse_proxy` do upstream (ex.: SSE sem buffer).";
          };

          comment = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Por que este serviço existe e por que este alcance — vai como comentário no Caddyfile gerado.";
          };
        };
      }
    );
  };
}
