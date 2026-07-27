# Sunshine — servidor de streaming de tela/desktop remoto (cliente = Moonlight). É
# a forma recomendada de acesso remoto no Hyprland/Wayland: captura por KMS (contorna
# as limitações do Wayland) e encoda por GPU. O Arc B580 tem encoder AV1/HEVC (VA-API)
# → stream fluido e de baixa latência. Chega-se no Sunshine PELA tailnet (Tailscale),
# não pela LAN/internet (openFirewall=false → só a interface tailscale0, que é trusted).
#
# Setup interativo (1x, do navegador de qualquer máquina na tailnet):
#   https://<ip-tailnet>:47990  → cria usuário/senha admin → pareia o Moonlight (PIN).
# O estado (clientes pareados) mora em ~/.config/sunshine (não declarável → é ESTADO).
{ ... }:

{
  services.sunshine = {
    enable = true;
    capSysAdmin = true; # cap p/ captura KMS (mirror da sessão física do Hyprland)
    autoStart = true; # sobe junto da sessão gráfica (serviço --user, WantedBy graphical-session)
    openFirewall = false; # NÃO abre na LAN/internet; acesso só pela tailnet (tailscale0 trusted)
    settings = {
      sunshine_name = "nixos-sandisk"; # nome que aparece no Moonlight
    };
  };
}
