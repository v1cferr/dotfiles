# Tailscale — mesh VPN (WireGuard) p/ acesso remoto seguro à máquina de casa sem
# port-forward. Atravessa NAT (inclusive corporativo) via relay DERP quando o UDP
# direto é bloqueado. Usado p/ chegar no Sunshine (system/services/sunshine.nix) e
# no SSH de qualquer rede. Cliente é open-source + WireGuard; o control server é
# proprietário (tier Personal grátis) — migração FOSS futura = Headscale self-hosted.
#
# Join DECLARATIVO: a auth key (sops, via Bitwarden) faz o `tailscale up` sozinho no
# 1º boot de QUALQUER máquina — sem passo manual (fresh-install reproduzível, regra 3).
# Depois o node key persiste em /var/lib/tailscale (estado → backup restic, regra 6);
# a auth key só serve pro join inicial. Gerar nova key: admin do Tailscale → Keys.
{ config, ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true; # abre a UDP 41641 (WireGuard direto; sem isto cai sempre no DERP)
    useRoutingFeatures = "client"; # aceita rotas/exit-node de outros nós, se um dia usar
    authKeyFile = config.sops.secrets.tailscale_authkey.path; # join sem `tailscale up` manual
  };

  # Confia na interface da tailnet: serviços com openFirewall=false (ex.: Sunshine)
  # ficam acessíveis PELA tailnet, mas continuam fechados na LAN/internet.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
