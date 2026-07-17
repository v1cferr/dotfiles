# CONFIG do Hyprland (~/.config/hypr/hyprland.conf), declarada. O compositor e a
# sessão vêm do system/ (programs.hyprland.enable); aqui é SÓ o arquivo de config
# (regra da pasta: home/ configura, não instala).
#
# Isto é uma base enxuta e usável (keybinds equivalentes ao exemplo default do
# Hyprland) já com ABNT2 e os monitores certos. Ponto de partida do rice — vai
# crescer com waybar, wallpaper, animações etc.
#
# Nota: por vir do /nix/store (read-only), mudanças exigem rebuild. Quando entrar
# na fase de iteração rápida, trocar por mkOutOfStoreSymlink pra hot-reload.
{ ... }:

{
  xdg.configFile."hypr/hyprland.conf".text = ''
    # ── Monitores ────────────────────────────────────────────────────────────
    # LG ULTRAGEAR (DP-1) à direita e como principal; HDMI-1 à esquerda.
    # Formato: nome,resolução@hz,posição,escala
    monitor = HDMI-1,1366x768@60,0x0,1
    monitor = DP-1,1920x1080@60,1366x0,1
    monitor = ,preferred,auto,auto   # qualquer outro monitor: auto
    workspace = 1,monitor:DP-1,default:true   # workspace principal no LG

    # ── Variáveis ────────────────────────────────────────────────────────────
    $mod = SUPER
    $terminal = kitty
    $menu = wofi --show drun

    # ── Input (teclado/mouse) ────────────────────────────────────────────────
    input {
      kb_layout = br          # ABNT2 (variante padrão do layout br)
      follow_mouse = 1
      sensitivity = 0
      touchpad {
        natural_scroll = true
      }
    }

    # ── Aparência ────────────────────────────────────────────────────────────
    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 2
      layout = dwindle
    }
    decoration {
      rounding = 6
    }
    animations {
      enabled = true
    }
    dwindle {
      pseudotile = true
      preserve_split = true
    }
    misc {
      force_default_wallpaper = 0   # sem o anime default do Hyprland
    }

    # ── Keybinds (equivalentes ao default) ───────────────────────────────────
    bind = $mod, Q, exec, $terminal
    bind = $mod, C, killactive
    bind = $mod, M, exit
    bind = $mod, V, togglefloating
    bind = $mod, F, fullscreen
    bind = $mod, R, exec, $menu
    bind = $mod, P, pseudo
    bind = $mod, J, togglesplit

    # foco (setas)
    bind = $mod, left, movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up, movefocus, u
    bind = $mod, down, movefocus, d

    # workspaces 1–10
    bind = $mod, 1, workspace, 1
    bind = $mod, 2, workspace, 2
    bind = $mod, 3, workspace, 3
    bind = $mod, 4, workspace, 4
    bind = $mod, 5, workspace, 5
    bind = $mod, 6, workspace, 6
    bind = $mod, 7, workspace, 7
    bind = $mod, 8, workspace, 8
    bind = $mod, 9, workspace, 9
    bind = $mod, 0, workspace, 10

    # mover janela pra workspace 1–10
    bind = $mod SHIFT, 1, movetoworkspace, 1
    bind = $mod SHIFT, 2, movetoworkspace, 2
    bind = $mod SHIFT, 3, movetoworkspace, 3
    bind = $mod SHIFT, 4, movetoworkspace, 4
    bind = $mod SHIFT, 5, movetoworkspace, 5
    bind = $mod SHIFT, 6, movetoworkspace, 6
    bind = $mod SHIFT, 7, movetoworkspace, 7
    bind = $mod SHIFT, 8, movetoworkspace, 8
    bind = $mod SHIFT, 9, movetoworkspace, 9
    bind = $mod SHIFT, 0, movetoworkspace, 10

    # mouse: mover/redimensionar janela
    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow
  '';
}
