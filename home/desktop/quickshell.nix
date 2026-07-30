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
  # CORREÇÃO (30/07): este comentário citava o xembedsniproxy como se ele existisse aqui, e
  # ele NÃO estava instalado — então este helper era código morto, justificado por um
  # comentário que descrevia um componente ausente. Agora o proxy é declarado de verdade
  # (ver systemd.user.services.xembedsniproxy no fim deste arquivo) e o caminho é real.
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

  # ── Ponte XEmbed → StatusNotifierItem ───────────────────────────────────────
  # App X11 legado (Wine/Bottles, e por isso o Battle.net) publica ícone de bandeja
  # pelo protocolo ANTIGO, o XEmbed (_NET_SYSTEM_TRAY_S0) — não pelo SNI que a barra
  # entende. Sem um host XEmbed, o Wine desiste e desenha a bandeja numa JANELINHA
  # própria: MEDIDO como `class=explorer.exe`, 160x20, flutuando sobre o desktop. Era
  # esse o incômodo — o ícone do Battle.net nunca chegava na barra.
  #
  # O xembedsniproxy hospeda a seleção XEmbed e republica cada ícone como SNI. VERIFICADO
  # ao vivo com o Battle.net aberto: subiu de 3 p/ 4 itens no StatusNotifierWatcher e a
  # janelinha do `explorer.exe` DESAPARECEU (o ícone foi embutido no proxy).
  #
  # CUSTO, medido e assumido: o binário só existe dentro do kdePackages.plasma-workspace,
  # que traz 758 MiB novos p/ este closure — 429 MiB deles são qtwebengine, mais kwin,
  # breeze e oxygen-icons. Feio num sistema Hyprland. As alternativas foram descartadas
  # com motivo: (a) `snixembed` faz o caminho INVERSO (publica SNI como XEmbed, p/ barras
  # antigas) e por isso tenta ser o próprio StatusNotifierWatcher — morre com "could not
  # acquire watcher name" porque o Quickshell já é o watcher; (b) não há pacote standalone
  # no nixpkgs (conferido: xembed-sni-proxy/xembedsniproxy não existem como atributo);
  # (c) extrair o binário à mão não escapa do peso — o plasma-workspace referencia kwin,
  # breeze e oxygen-icons DIRETAMENTE; (d) `stalonetray` seria outra janela flutuante,
  # ou seja, o problema original de volta.
  #
  # LIMITAÇÃO conhecida do ícone que vem por aqui (medido): ele NÃO tem nome nem menu —
  # `Id` é o window ID do X11 em decimal ("14680080"), `Title` e `ToolTip` vazios e
  # `Menu` inexistente. Por isso o clique-direito cai no tray-native-menu (acima) e por
  # isso um tooltip futuro não pode se contentar com o `Id`: p/ estes teria de resolver o
  # WM_CLASS da janela X11.
  #
  # ORDEM: o proxy precisa do watcher (o Quickshell) p/ registrar os itens, e o Quickshell
  # NÃO é uma unit systemd (sobe pelo exec-once do autostart.lua), então não há como
  # ordenar contra ele. O padrão SNI manda o item re-registrar quando o watcher aparece;
  # se algum dia o ícone não surgir no boot, é AQUI que se olha primeiro.
  systemd.user.services.xembedsniproxy = {
    Unit = {
      Description = "xembedsniproxy — ponte bandeja XEmbed (X11/Wine) → StatusNotifierItem";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Mesmo freio do autostart.nix: loop morre e FICA VISÍVEL em vez de rodar calado.
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/xembedsniproxy";
      # Precisa do X11 (XWayland). O DISPLAY vem do ambiente do systemd --user (medido:
      # DISPLAY=:0 presente) — NÃO chumbado aqui, senão quebra se o XWayland mudar de nº.
      # Se o XWayland ainda não estiver de pé, ele falha e as 3 tentativas dão a folga.
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
