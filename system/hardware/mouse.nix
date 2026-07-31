# Mouse Logitech MX Master 3S — configuração declarativa via logiops (daemon logid).
# logid roda como serviço systemd (root → acessa o hidraw) e aplica a config no hotplug.
# Conectado por Bluetooth (logiops 0.3.x já fala HID++ por BT); se um dia não detectar por
# BT, plugar o receptor Bolt (vem na caixa) resolve, sem mudar este arquivo.
{ pkgs, ... }:

{
  services.logiops = {
    enable = true;
    config = {
      devices = [
        {
          name = "MX Master 3S";
          dpi = 2222; # sensibilidade (nativo 1000; faixa 200–8000 — ajuste esta linha a gosto)

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

          # Rodinha do polegar → rola a fita do layout scrolling do Hyprland (ws 2 e 6).
          # Sintetiza SUPER+CTRL+,/. em vez de mandar scroll horizontal: keypress NÃO passa
          # pelo teto de 300ms do `binds:scroll_event_delay`, que travaria a rolagem em ~3
          # colunas/s (e baixar esse teto estragaria o SUPER+roda-vertical de workspace).
          # `interval = 1` é a verdade declarada: no thumbwheel o logiops dispara a cada
          # incremento independente do valor (issue #310, aberta) — por isso o bind do lado
          # do Hyprland move 80px, não 1 coluna: rajada de passo pequeno = rolagem suave.
          # CUSTO ACEITO: `divert` tira o scroll horizontal nativo DENTRO dos apps.
          thumbwheel = {
            divert = true;
            invert = false;
            left  = { mode = "OnInterval"; interval = 1; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_LEFTCTRL" "KEY_COMMA" ]; }; };
            right = { mode = "OnInterval"; interval = 1; action = { type = "Keypress"; keys = [ "KEY_LEFTMETA" "KEY_LEFTCTRL" "KEY_DOT" ]; }; };
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

  # logid tem BOOT-RACE + não re-detecta no reconnect: se o mouse conecta DEPOIS do logid
  # subir (BT pareia com atraso no boot, ou reconecta após dormir), o DPI fica no default
  # (1000), não nos 2500. MAS reiniciar o logid no INSTANTE do connect falha ("5 tries":
  # o HID++ do BT ainda não respondeu). Então o udev, quando o MX Master (046D:B034)
  # conecta, dispara um oneshot que ESPERA o HID++ acordar e SÓ AÍ reinicia o logid.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", KERNELS=="*046D:B034*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="logid-reapply.service"
  '';
  systemd.services.logid-reapply = {
    description = "Reaplica a config do logid quando o MX Master (BT) conecta e fica pronto";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5"; # espera o HID++ do BT acordar
      ExecStart = "${pkgs.systemd}/bin/systemctl try-restart logid.service";
    };
  };
}
