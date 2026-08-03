# Flameshot (screenshot) — v14 do canal UNSTABLE (pkgs.unstable.*, via overlay do
# flake.nix) + config + scripts do fluxo por teclado, no home (regra 4). Os binds
# (Print / SUPER+SHIFT+S + submap "screenshot") vivem em home/desktop/hypr/lua/keybinds.lua.
#
# Captura via xdg-desktop-portal (org.freedesktop.portal.Screenshot), servido pelo
# xdg-desktop-portal-wlr (system/desktop/desktop.nix; o -hyprland só DECLARA a interface,
# não implementa). Sem grim direto/useGrimAdapter → sem o aviso "grim ... GNOME".
#
# FLUXO POR TECLADO (paridade com o Arch v14): o v14 SEMPRE mostra um picker de monitor
# no multi-monitor (não dá pra pular nem com --region). O picker só aceita clique de
# mouse, então SUPER+SHIFT+S abre o picker + entra num submap; 1/2 SINTETIZAM o clique no
# preview do monitor certo (cursor + send_shortcut mouse:272). A janela do flameshot aqui
# tem class VAZIA + title "flameshot" → seletores e a window rule (rules.lua) usam título.
#
# NB: o .ini vem do /nix/store (read-only) → mudanças pela GUI NÃO persistem;
# editar aqui e rebuild. Qt QSettings NÃO aceita comentário inline no .ini.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Pacote do Quickshell (flake input). Ligado uma vez porque o caminho completo
  # passa de 130 colunas e se repetia em cada consumidor deste arquivo.
  qsPkg = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  fs = pkgs.unstable.flameshot; # v14

  # flameshot-screenshot: abre o picker (flameshot gui) e ENTRA no submap "screenshot"
  # (as teclas 1/2/Esc passam a valer). O watcher reseta o submap quando o flameshot
  # fecha (clique de mouse no picker, Esc interno ou timeout) — senão o 1/2 ficaria
  # sequestrado depois. Entrar/sair do submap via `hyprctl dispatch` (API Lua 0.55).
  flameshotScreenshot = pkgs.writeShellApplication {
    name = "flameshot-screenshot";
    # `qs`: esconde a barra enquanto o overlay existe (ver abaixo). runtimeInputs é
    # obrigatório — writeShellApplication usa PATH restrito, não o do usuário.
    runtimeInputs = [
      fs
      pkgs.hyprland
      pkgs.jq
      pkgs.coreutils
      qsPkg
    ];
    text = ''
      flameshot gui >/dev/null 2>&1 &
      hyprctl dispatch 'hl.dsp.submap("screenshot")' >/dev/null 2>&1 || true

      fs_open() { hyprctl clients -j | jq -e 'any(.[]; .title=="flameshot")' >/dev/null 2>&1; }
      (
        c=0; while [ "$c" -lt 15 ];  do sleep 0.2; fs_open && break;  c=$((c+1)); done  # espera abrir (≤3s)
        # BARRA DUPLICADA: aqui o frame CONGELADO do overlay já foi capturado — com a barra
        # dentro. Esconder a barra VIVA agora mata a duplicata SEM tirá-la do print. No
        # Hyprland janela normal NUNCA cobre layer `top`, e a barra vive nela; não há window
        # rule p/ inverter (feature request aberta, hyprwm/Hyprland#4847), então esconder é o
        # único caminho. Só esconde se abriu de fato, senão sumiria a barra à toa.
        fs_open && qs ipc call bar hide >/dev/null 2>&1 || true
        c=0; while [ "$c" -lt 300 ]; do fs_open || break; sleep 0.2;  c=$((c+1)); done  # espera fechar (≤60s)
        qs ipc call bar unhide >/dev/null 2>&1 || true  # SEMPRE volta, inclusive no timeout de 60s
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
      ) >/dev/null 2>&1 &
    '';
  };

  # flameshot-pick <monitor>: escolhe um monitor no picker do v14 SINTETIZANDO o clique.
  # Os previews ficam lado a lado na ORDEM FÍSICA (monitores por X, esq→dir); resolve a
  # fatia do alvo dinamicamente (nada chumbado → sobrevive a TV desligada / rearranjo).
  flameshotPick = pkgs.writeShellApplication {
    name = "flameshot-pick";
    runtimeInputs = [
      pkgs.hyprland
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      target="''${1:?uso: flameshot-pick <monitor>}"
      reset() { hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true; }

      # geometria do picker (janela title "flameshot"); sem picker → só reseta e sai.
      geo="$(hyprctl clients -j | jq -r '[.[] | select(.title=="flameshot")] | first
        | if . == null then empty else "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])" end')"
      if [ -z "$geo" ]; then reset; exit 0; fi
      read -r px py pw ph <<<"$geo"

      # índice 0-based do alvo na ordem esq→dir dos monitores ATIVOS + total n.
      info="$(hyprctl monitors -j | jq -r --arg t "$target" '
        ([ .[] | { name, x } ] | sort_by(.x)) as $m
        | ($m | map(.name) | index($t)) as $i
        | if $i == null then empty else "\($i) \($m | length)" end')"
      if [ -z "$info" ]; then reset; exit 0; fi  # alvo não ativo (ex.: TV desligada)
      read -r i n <<<"$info"

      # centro do preview: fatia i na horizontal, 55% da altura (sobre o preview).
      cx=$(( px + pw * (2 * i + 1) / (2 * n) ))
      cy=$(( py + ph * 55 / 100 ))
      hyprctl dispatch "hl.dsp.cursor.move({ x = $cx, y = $cy })" >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.send_shortcut({ mods = 0, key = "mouse:272", window = "title:flameshot" })' >/dev/null 2>&1 || true
      reset
    '';
  };

  # flameshot-cancel: Esc no submap → fecha o picker e sai do submap.
  flameshotCancel = pkgs.writeShellApplication {
    name = "flameshot-cancel";
    runtimeInputs = [ pkgs.hyprland ];
    text = ''
      hyprctl dispatch 'hl.dsp.window.close({ window = "title:flameshot" })' >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1 || true
    '';
  };
in
{
  # v14 (unstable) + os scripts do fluxo por teclado (chamados pelo submap em keybinds.lua).
  home.packages = [
    fs
    flameshotScreenshot
    flameshotPick
    flameshotCancel
  ];

  # ── Aliases de print, migrados do zsh do Arch ──────────────────────────────
  # Ficam AQUI, junto da ferramenta, e não no home/shell/zsh.nix — mesma convenção do
  # eza/bat, que moram no cli.nix (o zsh.nix guarda só os de shell/sistema).
  #
  # VERIFICADO no v14/Wayland desta máquina: só o `gui` abre o picker de monitor; o
  # `full` e o `screen --number` capturam DIRETO, sem picker. Ou seja, os aliases do
  # Arch continuam valendo — o que não vale é `--region`, que o v14 ignora.
  #
  # O `--number` é índice de tela do Qt, NÃO nome de monitor, então não sai do
  # my.monitors (regra 11 não se aplica: não há como derivar). Mapeamento medido
  # capturando as duas telas e comparando com os wallpapers: 0 = principal (DP-2),
  # 1 = TV (HDMI-A-3). Se o layout de monitores mudar, REMEDIR.
  # Os números herdados do Arch já casam com o submap de screenshot (1=TV, 2=principal).
  programs.zsh.shellAliases = {
    screenshot = "flameshot gui"; # seleção interativa (abre o picker do v14)
    scfull = "flameshot full -c"; # as duas telas → clipboard
    sc1 = "flameshot screen --number 1 -c"; # TV (HDMI-A-3) → clipboard
    sc2 = "flameshot screen --number 0 -c"; # principal (DP-2) → clipboard
  };

  # Pasta de saída dos prints (flameshot não cria sozinho de forma confiável).
  home.file."Pictures/Screenshots/.keep".text = "";

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    disabledTrayIcon=true
    showStartupLaunchMessage=false
    showDesktopNotification=true
    savePath=${config.home.homeDirectory}/Pictures/Screenshots
    savePathFixed=true
    saveAsFileExtension=.png
    contrastOpacity=128
    showHelp=false
    drawColor=#ff0000
    drawThickness=3
    uiColor=#${config.my.theme.palette.purple}
  '';
}
