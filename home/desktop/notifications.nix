# NOTIFICAÇÕES — swaync (SwayNotificationCenter), declarado. Sobe como serviço
# systemd --user. Trocou o mako: além do daemon de notificação, tem CENTRO DE
# CONTROLE (histórico, DND) e o módulo de barra (swaync-client -swb) que a
# home/desktop/waybar.nix usa. O cliente continua sendo o notify-send (libnotify):
# apps e scripts (OSD de brilho) mandam pra cá igual antes.
# Regra da pasta: app de USUÁRIO → home/. Ref: https://github.com/ErikReider/SwayNotificationCenter
{ ... }:

{
  services.swaync = {
    enable = true; # daemon + serviço systemd --user + swaync-client (módulo da waybar)

    # Comportamento (config.json do swaync).
    settings = {
      positionX = "right"; # notificações no canto superior-direito (igual era o mako)
      positionY = "top";
      control-center-positionX = "right"; # painel do centro de controle à direita
      control-center-positionY = "top";
      control-center-width = 400; # largura do painel
      notification-window-width = 400; # largura das notificações flutuantes
      timeout = 5; # some após 5s (igual mako)
      timeout-low = 3; # baixa prioridade: 3s
      timeout-critical = 0; # crítica: fica até você fechar
      notification-icon-size = 48; # ícone do app
      notification-body-image-height = 120; # altura de imagem embutida (ex.: capa de música)
      fit-to-screen = true; # painel ocupa a altura da tela
      keyboard-shortcuts = true; # navegar/fechar com teclado no painel
      # Widgets do centro de controle (ordem de cima p/ baixo).
      widgets = [ "title" "dnd" "notifications" ];
      widget-config = {
        title = {
          text = "Notificações";
          clear-all-button = true;
          button-text = "Limpar tudo";
        };
        dnd.text = "Não perturbe";
      };
    };

    # Estilo Tokyo Night (casa com o lockscreen/waybar).
    style = ''
      .control-center, .floating-notifications.background .notification-row .notification-background .notification {
        background: rgba(26, 27, 38, 0.96);
        border: 1px solid #414868;
        border-radius: 12px;
        color: #c0caf5;
        font-family: "JetBrainsMono Nerd Font";
      }
      .control-center { padding: 12px; }
      .notification-row .notification-background .notification {
        margin: 6px 4px;
        padding: 6px;
      }
      .notification-background .notification.critical { border-color: #f7768e; }
      .notification-background .notification.low { border-color: #565f89; }
      .notification-content { padding: 6px; }
      .summary { color: #7aa2f7; font-weight: bold; }
      .body { color: #a9b1d6; }
      .close-button {
        background: transparent;
        color: #565f89;
        border-radius: 8px;
      }
      .close-button:hover { background: #f7768e; color: #1a1b26; }
      .notification-action, .widget-title button {
        background: rgba(65, 72, 104, 0.4);
        color: #c0caf5;
        border: 1px solid #414868;
        border-radius: 8px;
      }
      .notification-action:hover, .widget-title button:hover {
        background: #7aa2f7;
        color: #1a1b26;
      }
      .widget-title { color: #c0caf5; font-size: 1.1em; margin: 4px 8px 10px 8px; }
      .widget-dnd { color: #c0caf5; margin: 4px 8px; }
      .widget-dnd > switch { background: #414868; border-radius: 12px; }
      .widget-dnd > switch:checked { background: #7aa2f7; }
    '';
  };
}
