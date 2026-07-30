# QUICKSHELL — o shell/bar em QML (bar, OSD, mídia, notificações), substituindo a
# waybar. O binário vem do FLAKE oficial (inputs.quickshell → sempre a última;
# bump com `nix flake update quickshell`).
#
# HOT-RELOAD (o motivo de ser assim): a config QML mora no REPO
# (home/desktop/quickshell/) e é linkada por mkOutOfStoreSymlink — um symlink pro
# arquivo MUTÁVEL, não pra store read-only. Assim o Quickshell recarrega o QML AO
# VIVO ao salvar (sem rebuild), e os arquivos seguem versionados no git (portável:
# outra máquina clona o repo no mesmo caminho e funciona). É um desvio consciente
# da regra 3 (não é symlink puro da store), padrão da comunidade p/ ricing de QML.
{ pkgs, config, inputs, ... }:

let
  # qs-restart: mata e sobe o Quickshell de novo. Necessário porque o hot-reload NÃO
  # reaplica delegate de Repeater (ws-pills, notificações) — editar o QML desses não
  # basta, precisa reiniciar o processo.
  #
  # POR QUE UM SCRIPT e não `qs kill; sleep 0.3; qs &` direto no bind: regra 7 (lógica
  # no build, bind = 1 comando) e regra 15 (dono explícito) — subir via `hyprctl
  # dispatch` faz o COMPOSITOR ser o pai, o mesmo dono do exec-once do autostart.lua,
  # em vez de o processo ser reparenteado ao init. De quebra o script funciona de um
  # shell fora da sessão, por causa do `-i 0`.
  #
  # CORREÇÃO (30/07): a versão anterior deste comentário afirmava que a forma antiga
  # NÃO reiniciava nada. Era FALSO. A evidência ("Quickshell com 5h de uptime depois de
  # apertar SUPER+ESCAPE") tinha causa banal: o usuário apertou SUPER+SPACE. Testada
  # depois, a forma antiga reinicia sim — o processo só termina com ppid=1 (systemd),
  # que é daemonização normal e sobrevive. Ou seja, isto é MELHORIA de arquitetura, não
  # correção de bug. Fica registrado porque inferir mecanismo a partir de uma observação
  # com explicação mais simples é justamente o erro que a regra 14 manda evitar.
  # tray-native-menu: dispara o menu de contexto NATIVO de um SNI que NÃO expõe DBusMenu
  # (ícones vindos do xembedsniproxy: wine/Battle.net, pamac). O `display()` do Quickshell
  # recusa item sem menu ("No menu present"), então chamamos o método ContextMenu() do SNI
  # na posição do cursor — o proxy repassa pro X11 e o app desenha o próprio menu ali.
  #
  # PORTADO do waybar do Arch (30/07): o Bar.qml chamava
  # `$HOME/.config/waybar/scripts/tray-native-menu.sh`, um caminho da WAYBAR — que foi
  # REMOVIDA na migração. O diretório não existe nesta máquina e o script não estava no
  # repo, então o clique-direito nesses ícones falhava em SILÊNCIO. Agora vive no build
  # (regra 7) e o QML o chama por NOME, pelo PATH.
  trayNativeMenu = pkgs.writeShellApplication {
    name = "tray-native-menu";
    runtimeInputs = with pkgs; [ hyprland systemd coreutils ];
    text = ''
      target_id="''${1:-}"
      [ -z "$target_id" ] && exit 2

      # posição global do cursor ("x, y") → dois inteiros
      pos="$(hyprctl cursorpos 2>/dev/null || true)"
      gx="''${pos%%,*}"; gy="''${pos##*,}"
      gx="''${gx//[[:space:]]/}"; gy="''${gy//[[:space:]]/}"
      case "$gx" in ""|*[!0-9]*) gx=0 ;; esac
      case "$gy" in ""|*[!0-9]*) gy=0 ;; esac

      items="$(busctl --user get-property org.kde.StatusNotifierWatcher \
        /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
        RegisteredStatusNotifierItems 2>/dev/null || true)"

      for tok in $items; do
        # entradas vêm entre aspas ("svc/path"); o "as" e a contagem não têm
        entry="''${tok//\"/}"
        [ "$entry" = "$tok" ] && continue
        svc="''${entry%%/*}"; path="/''${entry#*/}"
        id="$(busctl --user get-property "$svc" "$path" \
          org.kde.StatusNotifierItem Id 2>/dev/null || true)"
        id="''${id#s \"}"; id="''${id%\"}"
        if [ "$id" = "$target_id" ]; then
          busctl --user call "$svc" "$path" \
            org.kde.StatusNotifierItem ContextMenu ii "$gx" "$gy" 2>/dev/null
          exit 0
        fi
      done
      exit 1
    '';
  };

  qsRestart = pkgs.writeShellApplication {
    name = "qs-restart";
    runtimeInputs = [
      inputs.quickshell.packages.${pkgs.system}.default
      pkgs.hyprland
      pkgs.coreutils
    ];
    text = ''
      qs kill >/dev/null 2>&1 || true # sem instância rodando, o kill falha e está tudo bem
      sleep 0.3
      # `-i 0` acha a instância sem HYPRLAND_INSTANCE_SIGNATURE → funciona também por SSH.
      hyprctl -i 0 dispatch 'hl.dsp.exec_cmd("qs")'
    '';
  };
in
{
  home.packages = [
    inputs.quickshell.packages.${pkgs.system}.default # `qs` / `quickshell`
    pkgs.lm_sensors # `sensors` — CPU temp lido pelo bar/Bar.qml
    qsRestart # `qs-restart` — usado pelo bind SUPER+ESCAPE (keybinds.lua)
    trayNativeMenu # `tray-native-menu` — clique-direito em SNI sem DBusMenu (Bar.qml)
  ];

  # ~/.config/quickshell → arquivo real no repo (mutável) = hot-reload.
  xdg.configFile."quickshell".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/GitHub/v1cferr/dotfiles/home/desktop/quickshell";
}
