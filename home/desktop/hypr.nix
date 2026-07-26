# CONFIG do Hyprland em Lua (~/.config/hypr/hyprland.lua), declarada. O compositor
# e a sessão vêm do system/ (programs.hyprland.enable); aqui é SÓ o arquivo de
# config (regra da pasta: home/ configura, não instala).
#
# Formato Lua (Hyprland 0.55+): substitui o antigo hyprland.conf (hyprlang), que
# está deprecado. `hl` é um objeto global injetado pelo Hyprland. Se hyprland.lua
# existir, ele é carregado no lugar do .conf. Docs: https://wiki.hypr.land
#
# Keybinds/window-rules em PARIDADE com o setup Arch/Kingston (branch `arch`),
# com as ferramentas adaptadas ao stack NixOS (wofi/dolphin/quickshell).
#
# HOT-RELOAD: o hyprland.lua NÃO fica na store — vem por mkOutOfStoreSymlink do
# home/desktop/hypr/hyprland.lua (arquivo real no repo). Edita o .lua + `hyprctl
# reload` → aplica na hora, sem rebuild. Os scripts do Lua (minimize-others,
# brightness-osd) entram no PATH via home.packages, então o .lua os chama por nome.
{ pkgs, config, ... }:

let
  # minimize-others: manda as OUTRAS janelas da workspace atual pra special:minimized
  # (apertar de novo traz de volta). Reescrito p/ o dispatch Lua do 0.55 — o antigo
  # `hyprctl dispatch movetoworkspacesilent` quebrou; agora é hl.dsp.window.move com
  # follow=false (silencioso). jq/hyprctl entram no PATH do próprio script.
  minimizeOthers = pkgs.writeShellApplication {
    name = "minimize-others";
    runtimeInputs = with pkgs; [ hyprland jq coreutils ];
    text = ''
      active_json="$(hyprctl -j activewindow)"
      active_addr="$(jq -r '.address // empty' <<< "$active_json")"
      current_ws="$(jq -r '.workspace.id // empty' <<< "$active_json")"
      state="/tmp/hypr-minimized-ws-''${current_ws}.list"
      clients="$(hyprctl -j clients)"

      # Sem janela focada / workspace inválida → nada a fazer.
      if [ -z "$active_addr" ] || [ -z "$current_ws" ] || [ "$current_ws" = "-1" ]; then
        exit 0
      fi

      # Move uma janela específica (por endereço), sem seguir o foco. $1=addr $2=alvo.
      move() {
        hyprctl dispatch "hl.dsp.window.move({workspace=\"$2\", window=\"address:$1\", follow=false})" >/dev/null || true
      }

      # Toggle restaurar: se já minimizamos nesta workspace, traz tudo de volta.
      if [ -s "$state" ]; then
        while IFS= read -r addr; do
          if [ -n "$addr" ]; then move "$addr" "$current_ws"; fi
        done < "$state"
        rm -f "$state"
        exit 0
      fi

      # Endereços das outras janelas desta workspace (≠ a ativa).
      mapfile -t others < <(
        jq -r --arg a "$active_addr" --argjson w "$current_ws" \
          '.[] | select(.workspace.id==$w) | select(.address!=$a) | .address' <<< "$clients"
      )

      if [ "''${#others[@]}" -gt 0 ]; then
        printf '%s\n' "''${others[@]}" > "$state"
        for addr in "''${others[@]}"; do
          if [ -n "$addr" ]; then move "$addr" "special:minimized"; fi
        done
        [ -s "$state" ] || rm -f "$state"
        exit 0
      fi

      # Fallback: state perdido mas há janelas na special:minimized → restaura tudo.
      mapfile -t mins < <(
        jq -r '.[] | select(.workspace.name=="special:minimized") | .address' <<< "$clients"
      )
      for addr in "''${mins[@]}"; do
        if [ -n "$addr" ]; then move "$addr" "$current_ws"; fi
      done
    '';
  };

  # brightness-osd: "brilho" via gamma do hyprsunset (este desktop não tem backlight
  # real — brightnessctl/ddcutil ausentes) + OSD via notify-send (o Quickshell é o
  # daemon de notificação agora). Só tem efeito com o hyprsunset rodando. Uso:
  # brightness-osd up|down|reset.
  # Lê o gamma atual, calcula o novo e CLAMPA [floor, ceil] setando ABSOLUTO — o
  # hyprsunset só clampa o teto (max-gamma); embaixo ia a 0/negativo e bugava a tela.
  brightnessOsd = pkgs.writeShellApplication {
    name = "brightness-osd";
    runtimeInputs = with pkgs; [ hyprland libnotify coreutils ];
    text = ''
      step=10
      floor=20  # piso: nunca deixa a tela preta/bugada
      ceil=150  # teto = max-gamma do hyprsunset.nix

      # o gamma vem como FLOAT (ex.: "90.000015") → pega só a parte inteira (cut no
      # ponto), senão o tr juntaria os dígitos ("90000015") e o valor explodia.
      cur="$(hyprctl hyprsunset gamma 2>/dev/null | cut -d. -f1 | tr -dc '0-9' || true)"
      [ -n "$cur" ] || cur=100

      case "''${1:-up}" in
        up)    new=$((cur + step)) ;;
        down)  new=$((cur - step)) ;;
        reset) new=100 ;;           # volta pro brilho normal
        *)     new=$cur ;;
      esac

      if [ "$new" -lt "$floor" ]; then new=$floor; fi
      if [ "$new" -gt "$ceil" ];  then new=$ceil;  fi
      hyprctl hyprsunset gamma "$new" >/dev/null 2>&1 || true

      # x-canonical-private-synchronous: dica p/ o daemon trocar a notif no lugar (OSD).
      notify-send -h string:x-canonical-private-synchronous:brightness \
        -h "int:value:$new" "󰃞 Brilho" "$new%" || true
    '';
  };

  # hypr-monitor-watch: escuta os eventos do Hyprland (socket2) e dá `hyprctl reload`
  # quando um monitor CONECTA/DESCONECTA. O reload re-aplica a config → recalcula o
  # layout (mata o "monitor fantasma" — cursor indo pra tela que sumiu) e MOVE os
  # workspaces do monitor perdido pro que sobrou (TV fora → ws 5-8 caem no LG). Roda
  # como serviço systemd --user (não exec-once no Lua → não duplica no reload).
  monitorWatch = pkgs.writeShellApplication {
    name = "hypr-monitor-watch";
    runtimeInputs = with pkgs; [ hyprland socat coreutils ];
    text = ''
      sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
      socat -u "UNIX-CONNECT:$sock" - | while IFS= read -r line; do
        case "$line" in
          monitoradded*|monitorremoved*)
            sleep 0.4  # deixa o Hyprland assentar o hotplug antes do reload
            hyprctl reload >/dev/null 2>&1 || true
            ;;
        esac
      done
    '';
  };
in
{
  # Ferramentas da SESSÃO Hyprland que o Lua abaixo invoca (keybinds/autostart) —
  # app+config no home (regra 4). wofi = launcher; cliphist+wl-clipboard = histórico
  # de clipboard (+wl-clip-persist mantém a cópia após o app fechar); pamixer/playerctl
  # = teclas de mídia; pavucontrol = mixer GUI (SUPER+S).
  home.packages = with pkgs; [
    minimizeOthers # SUPER+M: minimiza as outras janelas (o Lua chama por nome)
    brightnessOsd # brilho via gamma do hyprsunset (SHIFT+Vol/0; chamado por nome)
    wofi
    cliphist
    wl-clipboard
    wl-clip-persist
    pamixer
    playerctl
    pavucontrol
  ];

  # Ociosidade (dim aos 3 min + lock aos 5 min) e a tela de bloqueio moram em
  # home/desktop/lockscreen.nix — hypridle/hyprlock via módulo (serviço systemd
  # --user), não mais .conf na mão. O SUPER+L (lock manual) está nos keybinds abaixo.
  # ~/.config/hypr/hyprland.lua → arquivo REAL no repo (mutável) = hot-reload: edita
  # home/desktop/hypr/hyprland.lua + `hyprctl reload`, SEM rebuild (mesmo esquema do
  # quickshell). Os scripts minimize-others/brightness-osd vão pro PATH (home.packages
  # abaixo), então o Lua os chama por NOME — por isso o .lua pode ser estático.
  xdg.configFile."hypr/hyprland.lua".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/hypr/hyprland.lua";

  # Sessão systemd do usuário. O LightDM lança o Hyprland "cru" (sem integração
  # systemd), então o graphical-session.target — que os serviços --user do desktop
  # (hyprsunset/hypridle) usam como WantedBy — nunca era ativado, e nenhum
  # subia no login. Este target o ativa via BindsTo (o graphical-session.target
  # recusa start manual, só por dependência); o autostart acima o inicia. Espelha o
  # que o módulo wayland.windowManager.hyprland faria — aqui a config é raw.
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Sessão do Hyprland (ativa o graphical-session.target)";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # Reaplica a config no hotplug de monitor (mata o fantasma + move workspaces).
  systemd.user.services.hypr-monitor-watch = {
    Unit = {
      Description = "Reaplica a config do Hyprland quando um monitor conecta/desconecta";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${monitorWatch}/bin/hypr-monitor-watch";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
