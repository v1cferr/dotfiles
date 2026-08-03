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

          # SEM bloco `thumbwheel` de propósito: a rodinha do polegar fica NATIVA (REL_HWHEEL),
          # que é o que faz o scroll horizontal funcionar DENTRO dos apps (VS Code, tabela
          # larga no browser, Dolphin). Quem rola a fita do Hyprland é SUPER + rodinha, por
          # bind em `mouse_left`/`mouse_right` (home/desktop/hypr/lua/keybinds.lua).
          # Já existiu aqui um `thumbwheel.divert = true` sintetizando SUPER+CTRL+,/. — a
          # razão era fugir do teto de 300ms do `binds:scroll_event_delay`, que estrangula
          # bind de roda em ~3 disparos/s. Virou desnecessário quando a fita passou a andar
          # de COLUNA em coluna (com column_width=1.0, 1 coluna = 1 tela): 3 telas/s é de
          # sobra, e o custo do divert (matar o scroll horizontal dos apps) não se pagava.
          # Se um dia precisar do divert de volta: `interval` é ignorado no thumbwheel — o
          # logiops dispara a cada incremento (PixlOne/logiops#310, aberta).

          buttons = [
            {
              cid = 195; # 0xC3 = botão de gestos (embaixo do apoio do polegar)
              # Gestos = GERÊNCIA DA FITA pelo polegar, desde que o scrolling virou global e
              # workspace deixou de ser onde se estoca janela. Cada gesto sintetiza um bind que
              # JÁ EXISTE no keybinds.lua — nada de ação nova só pro mouse, senão o cheatsheet
              # (SUPER+H, gerado do keybinds.lua) não enxergaria.
              # Trocar de workspace continua em SUPER+1..8, SUPER+TAB e SUPER+roda-vertical.
              action = {
                type = "Gestures";
                gestures = [
                  # Esquerda/Direita → MOVER a janela pela fita (SUPER+SHIFT+,/. = swapcol l/r).
                  # É o "pôr do lado com o mouse": o arrasto não faz isso (empilha, hardcoded).
                  {
                    direction = "Left";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTSHIFT"
                        "KEY_COMMA"
                      ];
                    };
                  }
                  {
                    direction = "Right";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTSHIFT"
                        "KEY_DOT"
                      ];
                    };
                  }
                  # Cima → VER TUDO (SUPER+CTRL+G = fit all) · Baixo → foco, 1 por tela
                  # (SUPER+CTRL+. = colresize all 1.0). O par de modos de visão, no polegar.
                  {
                    direction = "Up";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTCTRL"
                        "KEY_G"
                      ];
                    };
                  }
                  {
                    direction = "Down";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_LEFTCTRL"
                        "KEY_DOT"
                      ];
                    };
                  }
                  # Clique sem mover → launcher de apps (SUPER+Q).
                  {
                    direction = "None";
                    mode = "OnRelease";
                    action = {
                      type = "Keypress";
                      keys = [
                        "KEY_LEFTMETA"
                        "KEY_Q"
                      ];
                    };
                  }
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
