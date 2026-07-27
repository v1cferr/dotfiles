# Tailscale — mesh VPN (WireGuard) p/ acesso remoto seguro à máquina de casa sem
# port-forward. Atravessa NAT (inclusive corporativo) via relay DERP quando o UDP
# direto é bloqueado. Usado p/ chegar no Sunshine (system/services/sunshine.nix) e
# no SSH de qualquer rede. Cliente é open-source + WireGuard; o control server é
# proprietário (tier Personal grátis) — migração FOSS futura = Headscale self-hosted.
#
# Ativar (1x, interativo): `sudo tailscale up` → abre uma URL de login (autentica no
# navegador de outra máquina). Depois sobe sozinho no boot.
{ ... }:

{
  services.tailscale = {
    enable = true;
    openFirewall = true; # abre a UDP 41641 (WireGuard direto; sem isto cai sempre no DERP)
    useRoutingFeatures = "client"; # aceita rotas/exit-node de outros nós, se um dia usar
  };

  # Confia na interface da tailnet: serviços com openFirewall=false (ex.: Sunshine)
  # ficam acessíveis PELA tailnet, mas continuam fechados na LAN/internet.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
