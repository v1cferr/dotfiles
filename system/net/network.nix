# ═══════════════════════════════════════════════════════════════════════════
# REDE & ACESSO REMOTO — NetworkManager, SSH (exposto), fail2ban, DNS dinâmico
# e "nunca suspender". Tema: esta é uma máquina de acesso remoto por SSH.
# ═══════════════════════════════════════════════════════════════════════════
{ config, ... }:

{
  # ── Rede ───────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── VPN de casa: a faixa do WireGuard é CONFIÁVEL ──────────────────────────
  # O servidor WireGuard é o ROTEADOR (OpenWrt), não esta máquina — então NÃO existe
  # interface `wg0` local pra pôr em `trustedInterfaces`. O tráfego dos peers chega
  # pela LAN com origem 10.10.10.x, e a confiança precisa ser por ORIGEM.
  #
  # Isto SUBSTITUI o `trustedInterfaces = [ "tailscale0" ]` que morreu junto com o
  # Tailscale (08/08/2026), e é o que mantém o Sunshine alcançável PELO TÚNEL: ele roda
  # com `openFirewall = false` de propósito. Quem apagar isto tem que abrir as portas
  # dele.
  #
  # NÃO é mais o único caminho, e a frase anterior ("sem esta regra ele fica inacessível
  # de todo lugar") caducou em 10/08/2026: o acesso direto da UFSCar, sem VPN, tem
  # regras próprias em ../services/sunshine.nix. As duas coexistem de propósito — esta
  # cobre celular e qualquer peer novo; a de lá cobre o notebook da FAI, onde somar um
  # terceiro cliente de VPN seria conflito de rota. Apagar esta aqui NÃO derruba o
  # Moonlight da UFSCar, e apagar a de lá NÃO derruba o do túnel.
  #
  # `-I nixos-fw 1` e não `-A`. ⚠️ CORREÇÃO (08/08/2026): este comentário dizia que
  # "a cadeia termina num refuse, então `-A` nunca é alcançada", e isso é FALSO para
  # o extraCommands — lido no firewall-start GERADO, ele é injetado ANTES do
  # `-A nixos-fw -j nixos-fw-log-refuse`, então `-A` funcionaria. A frase só vale pra
  # regra digitada À MÃO num firewall já de pé. O `-I 1` continua sendo o certo por
  # outro motivo: é ele que reproduz a semântica do trustedInterfaces — a faixa
  # inteira passa antes de QUALQUER outra decisão da cadeia.
  # (Backend é iptables aqui: `networking.nftables.enable = false`.)
  networking.firewall = {
    extraCommands = ''
      iptables -I nixos-fw 1 -s ${config.my.net.vpnSubnet} -j nixos-fw-accept
    '';
    # Sem isto, `reload` do firewall empilha duplicatas da regra acima.
    extraStopCommands = ''
      iptables -D nixos-fw -s ${config.my.net.vpnSubnet} -j nixos-fw-accept 2>/dev/null || true
    '';
  };

  # ── SSH (espelha o Arch: porta 2222, root off, senha como fallback) ─────────
  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    openFirewall = true; # abre a 2222 no firewall
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
    };
  };

  # ── Nunca suspender ─────────────────────────────────────────────────────
  # É um desktop de acesso remoto (SSH). Se suspender, o SSH cai e você não
  # alcança de outro PC. Desativa todos os alvos de sono.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # ── Wake-on-LAN — o par do "nunca suspender": se a máquina ESTIVER desligada ─
  # ACHADO EM 10/08/2026, e o sintoma era invisível: o roteador tem TODAS as peças pra
  # acordar este PC — o script `/usr/bin/wake-desktop`, a regra NOPASSWD dele, e o MAC
  # alvo `7c:10:c9:a1:f4:e5`, que confere com esta enp7s0 — e nada acontecia, porque a
  # ponta que RECEBE estava desarmada. Medido: `Wake-on: d`, com `Supports Wake-on: pumbg`
  # (o `g` de magic packet existe na placa). Três peças certas apontando pra uma quarta
  # que não escuta: não dá erro em lugar nenhum, só não acorda.
  #
  # DECLARATIVO E NÃO `ethtool -s enp7s0 wol g`: o r8169 RESETA o WoL a cada boot, então a
  # forma imperativa se perde no próximo reboot — que é exatamente quando se precisa dela.
  # Esta opção vira `linkConfig.WakeOnLan` (nixos/modules/tasks/network-interfaces.nix),
  # aplicado pelo udev a cada subida do link.
  #
  # CONTRASTE com o `wake-workstation` de ../../home/net/fai-workstation.nix, que resolve o
  # MESMO problema e não pôde ser declarado: lá o receptor é uma Ubuntu de terceiro e o
  # conserto é netplan na mão, anotado em comentário. Aqui o receptor é esta máquina.
  #
  # ⚠️ NÃO COBRE QUEDA DE ENERGIA, e é o mal-entendido a evitar: corte real tira o +5VSB e
  # a NIC perde o registro armado. Pra "acabou a luz" quem responde é a BIOS (*Restore on
  # AC Power Loss* = Power On), que este repo não alcança. WoL serve pro desligamento
  # NORMAL, que é o caso comum.
  #
  # ⚠️ O NetworkManager tem `connection.wol` próprio. O default dele é não mexer, mas se
  # resetar numa mudança de link o sintoma é WoL funcionar logo após o boot e parar depois
  # — e isso só aparece desligando de verdade e mandando o magic packet. Literal `enp7s0`
  # e não opção: consumidor único (regra 11 pede 2+).
  networking.interfaces.enp7s0.wakeOnLan.enable = true;

  # ── fail2ban — protege o SSH exposto na internet ─────────────────────────
  # A 2222 fica aberta ao mundo (port-forward 2222 no OpenWrt) COM senha
  # habilitada → fail2ban é obrigatório. Espelha o jail do Arch: bane após 4
  # falhas em 10min, por 1h; nunca bane a LAN nem o loopback.
  services.fail2ban = {
    enable = true;
    bantime = "1h";
    # Vale pro [DEFAULT] do fail2ban, ou seja: TODAS as jails herdam, inclusive a
    # caddy-pos. Sem 127.0.0.1/8 e ::1 aqui de propósito — o módulo do nixpkgs já os
    # prepende, e declarar de novo saía duplicado no jail.local gerado.
    ignoreIP = [
      config.my.net.lanSubnet
      # A faixa do WireGuard entra junto: entrar de fora pela VPN e errar a senha do
      # SSH não pode banir o próprio caminho de volta.
      config.my.net.vpnSubnet
    ];
    jails.sshd.settings = {
      enabled = true;
      port = 2222;
      backend = "systemd"; # sshd loga no journald
      maxretry = 4;
      findtime = "10m";
    };
  };

  # ── DNS dinâmico (Cloudflare) ─────────────────────────────────────────────
  # Mantém ssh.<domínio> apontando pro IP público atual (que muda) → permite
  # `ssh …@ssh.<domínio>` de qualquer lugar, sem VPN. Token FORA do git
  # (via sops). proxied=false: registro DNS-only (cinza) — SSH não passa pelo
  # proxy HTTP da Cloudflare.
  #
  # Este registro é a ÂNCORA DE IP da zona inteira, e o único que o DDNS toca.
  # Os serviços NÃO ganham registro cada um: a zona usa um CURINGA
  # `*.<domínio>` CNAME apontando pra cá, então subdomínio novo funciona sem
  # nenhum trabalho de DNS — que é justamente o ponto do curinga.
  #
  # O IP publicado aqui É o desta casa, e ele RESPONDE de fora: o roteador tem o
  # público direto na `pppoe-wan` e encaminha 80/443/2222. Provado em 08/08/2026
  # pela borda da Cloudflare (registro proxied temporário → o Caddy devolveu o 404
  # do catch-all em 0,39s). Houve um susto de CGNAT em 07/08 que se provou FALSO —
  # o diagnóstico e as três formas de o teste mentir estão em docs/history/2026/08-august.md.
  #
  # ⚠️ NÃO adicione `*.<domínio>` aqui. Testado em 07/08/2026: o tool só sabe
  # criar/atualizar registro A, e a API recusa com o código 81054 ("A CNAME
  # record with that host already exists"). O serviço entra em loop de restart
  # e sai 3. O curinga tem que continuar CNAME, e é o alvo dele que faz a zona
  # seguir o IP — não o DDNS.
  #
  # ⚠️ NÃO CONFIE NO `dig` DE DENTRO DE CASA para auditar esta zona. O roteador
  # faz split-DNS de `*.<domínio>` → 192.168.1.10 e responde ANTES de qualquer
  # servidor externo — inclusive quando se aponta o dig direto pro autoritativo
  # (`dig @bruce.ns.cloudflare.com`). O sintoma é TTL 0 numa resposta que
  # deveria vir da Cloudflare. Custou uma investigação inteira em 07/08/2026:
  # a zona estava CERTA e parecia quebrada. Para ver o DNS de verdade, saia por
  # DoH (HTTPS, que o roteador não intercepta):
  #   curl -s -H 'accept: application/dns-json' \
  #     'https://cloudflare-dns.com/dns-query?name=ssh.<domínio>&type=A' | jq
  #
  # ⚠️ O cache (/var/lib/cloudflare-dyndns/ip.cache) compara o IP atual contra o
  # que ELE escreveu por último, nunca contra o registro real — alteração feita
  # pelo dashboard o deixa cego ("Every domain is up-to-date", sem chamar a API).
  # Apagá-lo força uma escrita real.
  #
  # O nome vem de `my.net.domain` (SSOT, regra 11 — ./domain.nix), nunca literal:
  # o Caddy e as jails do fail2ban leem a MESMA opção.
  services.cloudflare-dyndns = {
    enable = config.my.services.cloudflare-ddns;
    apiTokenFile = config.sops.secrets.cloudflare_ddns_token.path;
    domains = [ "ssh.${config.my.net.domain}" ];
    proxied = false;
    ipv4 = true;
    ipv6 = false;
  };

  # ESPERAR A REDE DE VERDADE. O módulo do nixpkgs ordena só por `network.target`
  # (services/networking/cloudflare-dyndns.nix:79), e esse target NÃO significa
  # "tem internet" — significa "a pilha de rede foi iniciada". Quem significa
  # conectividade é o `network-online.target`, e ele exige as DUAS pontas: o
  # `wants` (senão o target nem é puxado) e o `after` (senão não há ordem).
  #
  # MEDIDO no boot de 01/08: o serviço subiu em T+3s e o network-online só ficou
  # pronto em T+9,8s (a NetworkManager-wait-online leva 6,5s esperando DHCP).
  # Resultado, TODO boot: as quatro APIs de "qual é meu IP" davam unreachable, ele
  # APAGAVA o cache (`Deleting cache at: …/ip.cache`) e saía com status 2. O timer
  # de 5 min consertava depois — então isso nunca apareceu como quebrado, só como
  # um `failed` no boot que a gente aprendeu a ignorar. O custo real era o
  # ssh.v1cferr.dev ficar apontando pro IP velho na PIOR hora possível: logo depois
  # de uma queda de energia, que é justamente quando o IP público costuma mudar
  # e quando se quer entrar de fora.
  # HOUVE UMA SEGUNDA CAUSA, e ela MORREU com o Tailscale (08/08/2026): o
  # /etc/resolv.conf apontava pro 100.100.100.100, servido pelo próprio tailscaled, que
  # subia 11ms DEPOIS deste serviço — as quatro APIs de "qual é meu IP" falhavam por
  # resolução, não por rota. Isso exigia um `after = tailscaled.service` que agora não
  # tem mais alvo. Com o resolver de volta ao normal, a corrida de DNS não existe.
  #
  # O RETRY ABAIXO FICA, e não é resíduo: a primeira causa (DHCP demorando ~6,5s depois
  # do target) é independente do Tailscale e continua valendo. Tolerar a corrida e
  # tentar de novo é mais robusto que adivinhar ordem — o Restart deixa a janela de IP
  # velho em ≤20s, contra os ≤5min do timer. O StartLimit é o freio pra não virar loop
  # infinito quando a falha for real (token inválido, Cloudflare fora): 6 tentativas em
  # 5min e ele desiste, deixando o `failed` visível pro timer assumir depois.
  systemd.services.cloudflare-dyndns = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "20s";
    };
    unitConfig = {
      StartLimitIntervalSec = "5m";
      StartLimitBurst = 6;
    };
  };
}
