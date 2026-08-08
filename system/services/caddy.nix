# ═══════════════════════════════════════════════════════════════════════════
# CADDY — proxy reverso de TODOS os serviços expostos, sob `*.<domínio>`, com
# certificado CURINGA da Let's Encrypt (desafio DNS-01 via Cloudflare).
#
# Restaura o ingress que existia no Arch (branch `main`/`arch`,
# caddy/etc/caddy/Caddyfile) e que a migração pro NixOS deixou pra trás — é a
# "Fase 4 — Homelab" do README da branch nixos, agora declarativa.
#
# POR QUE UM SITE BLOCK CURINGA e não um vhost por subdomínio: é UM certificado
# em vez de ~10 pedidos ACME simultâneos. O roteamento por nome sai dos matchers
# `@host` abaixo, e subdomínio não mapeado cai no 404 do fim.
#
# POR QUE DNS-01 e não HTTP-01: curinga só é emitido por DNS-01. O preço é um
# Caddy com o plugin dns.providers.cloudflare. No Arch isso exigia buildar com
# xcaddy e ESCONDER o binário em /usr/local/bin, porque "um `pacman -Syu` já
# sobrescreveu o binário custom uma vez e derrubou o proxy inteiro"
# (scripts/caddy/build.sh do setup antigo). No Nix o pacote É a declaração:
# aquele problema deixa de existir, e o `hash` abaixo fixa o vendor de Go.
#
# ⚠️ `propagation_timeout -1` NÃO é chute. A checagem LOCAL de propagação do
# certmagic falha NESTE host mesmo forçando resolvers públicos, enquanto o
# registro propaga de verdade (8.8.8.8, 1.1.1.1 e o autoritativo confirmam) — e
# é o mundo que a LE consulta. Espera fixa de 30s + checagem local desligada faz
# a LE validar direto. Sem isso a emissão TRAVA.
#
# ⚠️ Os filtros do fail2ban casam a ORDEM DAS CHAVES do access log JSON
# (remote_ip … host … status, com `.+?` não-guloso). Bump de Caddy pode quebrá-los
# EM SILÊNCIO — o serviço segue de pé e simplesmente para de banir. Validar com
# `fail2ban-regex` a cada bump.
#
# AUTO-GATE (mesmo padrão do ./duo.nix): só ativa quando os QUATRO segredos
# existirem. Enquanto não provisionar, fica INERTE e o sistema segue buildando —
# importante porque `{$VAR}` vazio viraria hash de basic_auth vazio, e o Caddy
# recusaria a config inteira.
#
# Ligar (uma vez):
#   1. Cloudflare → API token com `Zone:Read + DNS:Edit` NA ZONA. É um token
#      SEPARADO do DDNS (o setup antigo também mantinha dois).
#   2. `caddy hash-password` uma vez por usuário do basic_auth.
#   3. Bitwarden: crie os itens (o VALOR vai sempre no campo *senha*):
#        "Caddy ACME Email"        (e-mail de avisos da Let's Encrypt)
#        "Caddy Cloudflare DNS"    (o token do passo 1)
#        "Caddy Pos Hash v1cferr"  (hash bcrypt)
#        "Caddy Pos Hash jp"       (hash bcrypt do João Pedro)
#   4. secrets/bitwarden-secrets.json: some as quatro linhas correspondentes.
#   5. `sync-secrets` → `sudo nixos-rebuild switch --flake .#nixos-kingston`
#   6. DNS na Cloudflare: `pos.<domínio>` = CNAME → `ssh.<domínio>`,
#      proxied=false (cinza). O A record do `ssh` é a âncora de IP; quem o mantém
#      é o DDNS em ../net/network.nix.
#
# MAPA DE PORTAS DE LOOPBACK — herdado do setup antigo. Projeto novo escolhe uma
# livre e ANOTA aqui, senão a próxima colisão é silenciosa:
#   3000 open-webui · 3001 spendflow · 3003 homepage · 3004 filebrowser
#   3005 housing-radar · 3006 GRAD-RADAR (front) · 3010 duo-web
#   8000 spendflow-api (reservada) · 8006 GRAD-RADAR (api) · 8010 duo-api
#   8080 qbittorrent · 8096 jellyfin · 11434 ollama
#
# ESTADO (regra 6): /var/lib/caddy guarda a conta ACME e os certificados. Não se
# declara — e vale backup, porque a LE limita 5 certificados DUPLICADOS por
# semana: perder o store custa uma janela de reemissão, não só um rebuild.
# O Caddyfile tem UM DONO, o Nix (regra 14) — nada de `caddy reload` gravando
# por cima.
# ═══════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:

let
  domain = config.my.net.domain;

  # Ponto e vírgula do regex: o domínio entra em failregex do fail2ban, onde `.`
  # é curinga. Escapar evita que `pos.v1cferr.dev` case `posXv1cferrYdev`.
  domainRe = builtins.replaceStrings [ "." ] [ "\\." ] domain;

  # AUTO-GATE: os quatro são necessários JUNTOS. Faltando um, `{$VAR}` vira
  # string vazia e o Caddy recusa a config (hash de basic_auth vazio) — melhor
  # ficar inerte do que derrubar o proxy no switch.
  requiredSecrets = [
    "caddy_acme_email"
    "caddy_cloudflare_dns_token"
    "caddy_pos_hash_v1cferr"
    "caddy_pos_hash_jp"
  ];
  enabled = lib.all (s: builtins.hasAttr s config.sops.secrets) requiredSecrets;
in
lib.mkIf (enabled && config.my.services.caddy) {
  services.caddy = {
    enable = true;

    # Caddy + plugin de DNS da Cloudflare (exigido pelo DNS-01 do curinga).
    # O `hash` é do vendor de Go: muda quando a versão do Caddy ou do plugin
    # muda. Rebuild reclamando de hash → recalcular com lib.fakeHash e ler o
    # valor esperado no erro.
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-7GoH8YLCoPmPExQxoga2FHB58zQDoZVf1BBwkVi0SsQ=";
    };

    # Segredos por ambiente, nunca na /nix/store (regra 12): o Caddyfile guarda
    # só os placeholders `{$VAR}`, resolvidos em runtime a partir deste arquivo.
    environmentFile = config.sops.templates."caddy.env".path;

    # CA fixada em PRODUÇÃO de propósito: estado antigo de staging já fez o Caddy
    # servir certificado inválido sem avisar.
    globalConfig = ''
      email {$CADDY_ACME_EMAIL}
      acme_ca https://acme-v02.api.letsencrypt.org/directory
    '';

    virtualHosts."*.${domain}" = {
      # Access log JSON → stderr → journald, que é de onde as jails do fail2ban
      # leem (`journalmatch = _SYSTEMD_UNIT=caddy.service`). Sem `format json` os
      # filtros não casam nada.
      logFormat = "format json";

      extraConfig = ''
        tls {
          dns cloudflare {$CADDY_CLOUDFLARE_DNS_TOKEN}
          resolvers 1.1.1.1 1.0.0.1
          propagation_delay 30s
          propagation_timeout -1
        }

        # Rede "de casa" = LAN + túnel WireGuard do roteador + loopback. Definido
        # UMA vez e reusado por todos os handles abaixo (matcher nomeado vale no
        # site block inteiro).
        #
        # O 10.10.10.0/24 funciona porque o servidor WireGuard é o ROTEADOR
        # (OpenWrt) e o caminho wg → lan não faz NAT, então o IP de origem chega
        # preservado até aqui. Se um dia o WireGuard mudar pro host, esta faixa
        # muda junto.
        #
        # ⚠️ No Arch esta lista estava duplicada e DIVERGENTE: o `duo` incluía a
        # faixa do WireGuard e o `ai` não, por esquecimento de backfill. Unificar
        # aqui ESTENDE o acesso do `ai` aos clientes de VPN — decisão consciente,
        # não efeito colateral.
        @externo not remote_ip 192.168.1.0/24 10.10.10.0/24 127.0.0.1/8 ::1

        # ---- Projetos ----

        # GradRadar (V1C-72) — radar de pós-graduação, compartilhado com o JP.
        # Ainda NÃO tem login próprio (as rotas de escrita chegam no F2), então
        # quem vem de fora passa por basic_auth; na LAN abre direto. Mesmo padrão
        # que o `dash` usava no Arch. Usuários separados de propósito: dá pra
        # revogar um sem mexer no outro, e o log distingue quem errou a senha.
        @pos host pos.${domain}
        handle @pos {
          basic_auth @externo {
            v1cferr {$CADDY_POS_HASH_V1CFERR}
            jp {$CADDY_POS_HASH_JP}
          }

          # /api/* vai pro FastAPI, o resto pro Next. O prefixo /api NÃO é
          # removido: a mesma URL funciona batendo direto no container, o que
          # simplifica debug com `docker compose exec`.
          handle /api/* {
            reverse_proxy 127.0.0.1:8006
          }
          handle {
            reverse_proxy 127.0.0.1:3006
          }
        }

        # duo-streak-daemon (V1C-71) — console Next.js; /api/* segue via Next
        # pra API em 8010. Expõe detalhes da automação, então é só rede de casa.
        @duo host duo.${domain}
        handle @duo {
          respond @externo "Forbidden" 403
          reverse_proxy 127.0.0.1:3010 {
            # SSE (/api/events): stream sem buffer.
            flush_interval -1
          }
        }

        # ---- IA / LLMs ----

        # Ollama NÃO tem autenticação nativa — só rede de casa. De fora, 403.
        @ai host ai.${domain}
        handle @ai {
          respond @externo "Forbidden" 403
          reverse_proxy 127.0.0.1:11434
        }

        # ---- Mídia ----

        # Jellyfin e qBittorrent têm login próprio, então ficam expostos (mesmo
        # nível do setup antigo). No Arch o Jellyfin era container com
        # network_mode:host bindado na IP da LAN; o serviço nativo do NixOS
        # escuta em 0.0.0.0, então aqui o upstream é loopback.
        @jellyfin host jellyfin.${domain}
        handle @jellyfin {
          reverse_proxy 127.0.0.1:8096
        }

        @torrent host torrent.${domain}
        handle @torrent {
          reverse_proxy 127.0.0.1:8080
        }

        # Subdomínio não mapeado → 404 limpo, em vez de erro feio do Caddy.
        handle {
          respond "Subdomínio não configurado" 404
        }
      '';
    };
  };

  # PRIMEIRO `allowedTCPPorts` do repo. Todo o resto usa o `openFirewall` do
  # módulo upstream, mas `services.caddy` não tem um. O roteador (OpenWrt) já
  # encaminha 80/443/2222 desde o setup antigo — quem bloqueava era o firewall
  # do NixOS, ligado por padrão. 80 fica aberta porque o Caddy redireciona pra
  # 443 e porque um dia pode fazer falta pro HTTP-01 de um domínio sem DNS-01.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Renderiza o .env do Caddy: config em texto + segredos por placeholder.
  # ASPAS SIMPLES nos hashes: bcrypt contém `$`, e o `.env` do setup antigo já
  # documentava que sem elas o valor é mutilado antes de chegar no processo.
  sops.templates."caddy.env".content = ''
    CADDY_ACME_EMAIL=${config.sops.placeholder.caddy_acme_email}
    CADDY_CLOUDFLARE_DNS_TOKEN=${config.sops.placeholder.caddy_cloudflare_dns_token}
    CADDY_POS_HASH_V1CFERR='${config.sops.placeholder.caddy_pos_hash_v1cferr}'
    CADDY_POS_HASH_JP='${config.sops.placeholder.caddy_pos_hash_jp}'
  '';

  # ── fail2ban: brute-force no basic_auth do `pos` ──────────────────────────
  # Mora aqui e não em ../net/network.nix (onde o serviço é declarado) porque a
  # jail só existe por causa deste proxy: quem apaga o vhost tem que apagar a
  # jail junto, e o acoplamento fica visível.
  #
  # O basic_auth só devolve 401 quando a senha está errada → 401 no host do
  # `pos` é tentativa falha, não navegação normal.
  environment.etc."fail2ban/filter.d/caddy-pos.conf".text = ''
    # Falhas de basic_auth no Caddy (host pos.${domain}), lidas do access log
    # JSON no journald. ⚠️ Depende da ORDEM das chaves do log — validar com
    # `fail2ban-regex` depois de bump do Caddy.
    [Definition]
    failregex = "remote_ip":"<HOST>",.+?"host":"pos\.${domainRe}",.+?"status":401,
    journalmatch = _SYSTEMD_UNIT=caddy.service
  '';

  services.fail2ban.jails.caddy-pos.settings = {
    enabled = true;
    filter = "caddy-pos";
    backend = "systemd"; # o Caddy loga no journald, não em arquivo
    port = "http,https";
    maxretry = 5;
    findtime = "10m";
    bantime = "1h";
    # Não banir a rede de casa — na LAN o basic_auth nem é exigido.
    ignoreip = "127.0.0.1/8 ::1 192.168.1.0/24 10.10.10.0/24";
  };
}
