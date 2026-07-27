# Mouse Logitech MX Master 3S — configuração declarativa via logiops (daemon logid).
# logid roda como serviço systemd (root → acessa o hidraw) e aplica o /etc/logid.cfg no
# hotplug. Conectado por Bluetooth (logiops 0.3.x já fala HID++ por BT); se um dia não
# detectar por BT, plugar o receptor Bolt (vem na caixa) resolve, sem mudar este arquivo.
{ ... }:

{
  services.logiops = {
    enable = true;
    config = {
      devices = [
        {
          name = "MX Master 3S";
          dpi = 2000; # sensibilidade (nativo 1000; faixa 200–8000 — ajuste esta linha a gosto)

          # Roda inteligente: alterna catraca ↔ giro-livre pela força do giro.
          smartshift = {
            on = true;
            threshold = 15; # força p/ soltar a catraca (menor = solta mais fácil)
          };

          # Scroll de alta resolução (suave, pixel a pixel).
          hiresscroll = {
            hires = true;
            invert = false;
            target = false;
          };

          buttons = [
            {
              cid = 195; # 0xC3 = botão de gestos (embaixo do apoio do polegar)
              action = {
                type = "Gestures";
                gestures = [
                  # Esquerda/Direita → trocar de workspace no Hyprland.
                  { direction = "Left"; mode = "OnRelease"; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_LEFTSHIFT" "KEY_TAB" ]; }; }
                  { direction = "Right"; mode = "OnRelease"; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_TAB" ]; }; }
                  # Cima → fullscreen · Baixo → minimizar as outras janelas.
                  { direction = "Up"; mode = "OnRelease"; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_F" ]; }; }
                  { direction = "Down"; mode = "OnRelease"; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_M" ]; }; }
                  # Clique sem mover → launcher de apps (SUPER+Q).
                  { direction = "None"; mode = "OnRelease"; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_Q" ]; }; }
                ];
              };
            }
          ];
        }
      ];
    };
  };
}
