# NOTIFICAÇÕES — mako (daemon Wayland), declarado. Sobe como serviço systemd
# --user (igual hypridle/hyprsunset/hyprlock). O cliente é o notify-send
# (libnotify): apps e scripts (OSD de brilho, VPN quando migrar) mandam pra cá.
# Regra da pasta: app de USUÁRIO → home/. Ref: https://wiki.hypr.land (notif).
{ ... }:

{
  services.mako = {
    enable = true; # habilita o daemon + serviço systemd --user
    settings = {
      # Tokyo Night discreto (casa com o lockscreen), canto superior-direito, 5s.
      background-color = "#1a1b26"; # fundo (escuro)
      text-color = "#c0caf5"; # texto (claro)
      border-color = "#7aa2f7"; # borda azul
      border-size = 2; # espessura da borda
      border-radius = 8; # cantos arredondados
      default-timeout = 5000; # some sozinha após 5s
      font = "JetBrainsMono Nerd Font 11"; # mesma fonte do resto do desktop
    };
  };
}
