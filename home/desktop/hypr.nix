# CONFIG do Hyprland em Lua (~/.config/hypr/hyprland.lua), declarada. O compositor
# e a sessão vêm do system/ (programs.hyprland.enable); aqui é SÓ o arquivo de
# config (regra da pasta: home/ configura, não instala).
#
# Formato Lua (Hyprland 0.55+): substitui o antigo hyprland.conf (hyprlang), que
# está deprecado. `hl` é um objeto global injetado pelo Hyprland. Se hyprland.lua
# existir, ele é carregado no lugar do .conf. Docs: https://wiki.hypr.land
#
# Keybinds/window-rules em PARIDADE com o setup Arch/Kingston (branch `arch`),
# com as ferramentas adaptadas ao stack NixOS (wofi/dolphin/waybar). Nota: vindo
# do /nix/store (read-only), mudanças exigem rebuild; na iteração rápida, trocar
# por mkOutOfStoreSymlink p/ hot-reload.
{ pkgs, ... }:

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
  # real — brightnessctl/ddcutil ausentes) + OSD no mako (notify-send com replace
  # in-place). Só tem efeito com o hyprsunset rodando. Uso: brightness-osd up|down.
  brightnessOsd = pkgs.writeShellApplication {
    name = "brightness-osd";
    runtimeInputs = with pkgs; [ hyprland libnotify coreutils ];
    text = ''
      step=10
      case "''${1:-up}" in
        up)   hyprctl hyprsunset gamma "+$step" >/dev/null 2>&1 || true ;;
        down) hyprctl hyprsunset gamma "-$step" >/dev/null 2>&1 || true ;;
      esac

      # gamma resultante (o hyprsunset já clampa); se o serviço estiver off, mostra 100.
      g="$(hyprctl hyprsunset gamma 2>/dev/null | tr -dc '0-9' || true)"
      [ -n "$g" ] || g=100

      # x-canonical-private-synchronous → o mako troca a notificação no lugar (vira OSD).
      notify-send -h string:x-canonical-private-synchronous:brightness \
        -h "int:value:$g" "󰃞 Brilho" "$g%" || true
    '';
  };
in
{
  # Ociosidade (dim aos 3 min + lock aos 5 min) e a tela de bloqueio moram em
  # home/lockscreen.nix — hypridle/hyprlock via módulo (serviço systemd --user),
  # não mais .conf na mão. O SUPER+L (lock manual) está nos keybinds abaixo.
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- ── Monitores ────────────────────────────────────────────────────────────
    -- Nomes de conector confirmados via `hyprctl monitors` (Wayland/Arc):
    --   DP-2     = LG ULTRAGEAR (1080p 144Hz) → PRINCIPAL, na origem 0x0
    --   HDMI-A-3 = TV LG → à esquerda (x negativo), em Full HD (1920x1080@60).
    -- Adaptação p/ TV desconectada: com o principal em 0x0, o LG segue sozinho sem
    -- offset fantasma; as workspaces 5–8 recaem nele automaticamente.
    hl.monitor({ output = "DP-2",     mode = "1920x1080@143.98", position = "0x0",     scale = 1 })
    hl.monitor({ output = "HDMI-A-3", mode = "1920x1080@60",     position = "-1920x0", scale = 1 })
    hl.monitor({ output = "",         mode = "preferred",        position = "auto",    scale = "auto" })

    -- 4 workspaces por monitor: 1–4 no LG (DP-2, principal), 5–8 na TV (HDMI-A-3).
    -- default:true = a workspace que abre em cada monitor no boot da sessão.
    hl.workspace_rule({ workspace = "1", monitor = "DP-2",     default = true })
    hl.workspace_rule({ workspace = "2", monitor = "DP-2" })
    hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
    hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
    hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-3", default = true })
    hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-3" })
    hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-3" })
    hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-3" })

    -- ── Programas (paridade com o Arch, ferramentas adaptadas ao NixOS) ────────
    local terminal       = "kitty"              -- SUPER+RETURN
    local terminalWithAi  = "kitty claude"      -- SUPER+BACKSPACE (Claude Code no terminal)
    local launcherApps   = "wofi --show drun"   -- SUPER+Q (apps .desktop) [era rofi drun]
    local launcherRun    = "wofi --show run"    -- SUPER+R (binários no PATH) [era rofi run]
    local fileManager    = "dolphin"            -- SUPER+E [era thunar]
    local sound          = "pavucontrol"        -- SUPER+S (mixer de áudio)
    local bluetooth      = "blueman-manager"    -- SUPER+B

    -- ── Ambiente ─────────────────────────────────────────────────────────────
    -- Cursor: Bibata-Modern-Ice (pacote bibata-cursors vem do system/). XCURSOR_*
    -- cobre XWayland/apps legados e o fallback do Hyprland; HYPRCURSOR_* é o
    -- formato nativo (cai no XCursor se não houver variante hyprcursor do tema).
    -- Apps GTK pegam o cursor pelo gsettings (home/theme.nix), não daqui.
    hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
    hl.env("HYPRCURSOR_SIZE", "24")

    -- Tema Qt/KDE (Dolphin): faz o Qt seguir o GTK escuro. O módulo qt
    -- (home/theme.nix) já define isso como session var, mas em Wayland a sessão
    -- nem sempre carrega — fixar aqui garante o dark nos apps abertos pelo Hyprland.
    hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
    hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")

    -- Qt roda nativo em Wayland (fallback xcb): o flameshot precisa disso pra
    -- posicionar o overlay/picker certo; xcb cobre qualquer app Qt sem Wayland.
    hl.env("QT_QPA_PLATFORM", "wayland;xcb")

    -- ── Autostart ────────────────────────────────────────────────────────────
    -- hyprland.start dispara UMA vez no boot da sessão (não em reload). O hypridle
    -- NÃO entra aqui: sobe como serviço systemd --user (home/lockscreen.nix).
    hl.on("hyprland.start", function()
      -- Sessão systemd --user: importa o env do Wayland e inicia o hyprland-session.target
      -- (BindsTo graphical-session.target). Sem isto os serviços --user (hyprsunset/hypridle/
      -- mako) NÃO sobem no login — o LightDM lança o Hyprland cru, sem integração systemd.
      -- O target está declarado em systemd.user.targets (abaixo do xdg.configFile).
      hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
      hl.exec_cmd("waybar")
      -- watcher do clipboard: escuta cada cópia e grava no histórico do cliphist.
      -- Sem isto o cliphist fica vazio (é o daemon que popula o banco).
      hl.exec_cmd("wl-paste --watch cliphist store")
      -- clipboard persistente: mantém a cópia viva após o app de origem fechar. No
      -- Wayland o dono do clipboard é a app; sem isto a imagem do Flameshot some ao
      -- ele sair (Ctrl+V não cola). Casa com o cliphist (histórico) acima.
      hl.exec_cmd("wl-clip-persist --clipboard regular")
    end)

    -- ── Aparência ────────────────────────────────────────────────────────────
    hl.config({
      general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
      },
      decoration = {
        rounding = 6,
      },
      animations = {
        enabled = true,
      },
      dwindle = {
        preserve_split = true,
      },
      misc = {
        force_default_wallpaper = 0,  -- sem o wallpaper anime default
      },
    })

    -- ── Input (teclado/mouse) ────────────────────────────────────────────────
    hl.config({
      input = {
        kb_layout = "br",   -- ABNT2 (variante padrão do layout br)
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
          natural_scroll = true,
        },
      },
    })

    -- ── Keybinds (paridade com o Arch/Kingston) ───────────────────────────────
    local mainMod = "SUPER"

    -- Apps e ações principais
    hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(launcherApps))                 -- launcher (apps)
    hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(launcherRun))                  -- launcher (run)
    hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(terminal))                     -- terminal
    hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(terminalWithAi))               -- terminal c/ IA (Claude Code)
    hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))                  -- arquivos (Dolphin)
    hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd(sound))                        -- mixer de áudio
    hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(bluetooth))                    -- bluetooth
    hl.bind(mainMod .. " + C",         hl.dsp.window.close())                         -- fechar janela
    hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))    -- flutuar
    hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))  -- fullscreen
    hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())                        -- pseudo (dwindle)
    hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl reload"))             -- recarregar config
    -- lock: loginctl → logind → lock_cmd do hypridle (home/lockscreen.nix); nunca duplica o hyprlock.
    hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))      -- travar tela

    -- clipboard: histórico do cliphist no wofi; a escolha volta pro clipboard (cole com Ctrl+V).
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

    -- reiniciar a Waybar (no Arch era o restart do Quickshell; aqui a barra é a Waybar).
    hl.bind(mainMod .. " + ESCAPE",    hl.dsp.exec_cmd("bash -lc 'pkill -x waybar; sleep 0.3; waybar &'"))

    -- VPN (SUPER+N / SHIFT+N / CTRL+N): PENDENTE — backend ainda não migrado
    -- (netExtender da FAI não está no nixpkgs; UFSCar é conexão NetworkManager c/ segredo).

    -- Minimizar: manda as OUTRAS janelas da workspace pra special:minimized (toggle).
    hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("${minimizeOthers}/bin/minimize-others"))
    hl.bind(mainMod .. " + CTRL + M",  hl.dsp.workspace.toggle_special("minimized"))  -- abrir/fechar a special

    -- Foco entre janelas (setas)
    hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

    -- Foco por monitor: F1 = LG (DP-2, principal) · F2 = TV (HDMI-A-3)
    hl.bind(mainMod .. " + F1", hl.dsp.focus({ monitor = "DP-2" }))
    hl.bind(mainMod .. " + F2", hl.dsp.focus({ monitor = "HDMI-A-3" }))

    -- Workspaces 1–8 (SUPER troca; SUPER+SHIFT move a janela). 1–4 no LG, 5–8 na TV.
    for i = 1, 8 do
      hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
      hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    end

    -- Navegação relativa (workspace anterior/próxima) por TAB e por scroll do mouse.
    hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
    hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))

    -- Mover a janela ativa entre monitores: CTRL+← p/ TV (esquerda), CTRL+→ p/ LG (direita).
    hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ monitor = "HDMI-A-3" }))
    hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ monitor = "DP-2" }))

    -- Mouse: mover / redimensionar janela
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- ── Teclas de mídia / volume / brilho ──────────────────────────────────────
    -- locked = funciona com a tela travada; repeating = repete enquanto segura.
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- +vol (teto 100%)
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- -vol
    hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })  -- mudo saída
    hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })  -- mudo microfone
    -- play/pause/next/prev via playerctl (só locked; não faz sentido repetir).
    hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
    -- brilho = gamma do hyprsunset (desktop sem backlight); OSD via mako.
    hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("${brightnessOsd}/bin/brightness-osd up"),   { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${brightnessOsd}/bin/brightness-osd down"), { locked = true, repeating = true })
    -- alternativa sem teclas dedicadas de brilho: SHIFT + teclas de volume.
    hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("${brightnessOsd}/bin/brightness-osd up"),   { locked = true, repeating = true })
    hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("${brightnessOsd}/bin/brightness-osd down"), { locked = true, repeating = true })

    -- ── Window rules ───────────────────────────────────────────────────────────
    -- Transparência sutil em tudo: ativa 0.98 / inativa 0.96 (contraste + wallpaper).
    hl.window_rule({ match = { class = ".*" }, opacity = "0.98 0.96" })
    -- Ignora pedidos de "maximizar" dos apps (comporta melhor no tiling).
    hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
    -- Fix de drag do XWayland: janelas sem class/title, flutuantes, que roubam foco.
    hl.window_rule({
      match = { class = "^$", title = "^$", xwayland = 1, float = 1, fullscreen = 0 },
      suppress_event = "activate activatefocus",
    })
    -- Picture-in-Picture (vídeo destacado) sempre 100% opaco.
    hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, opacity = "1.0" })
    -- Ascension (WoW privado via Wine): flutuante centralizado no LG, opaco, sem idle-lock.
    hl.window_rule({
      match = { class = "^(ascension\\.exe)$" },
      float = true,
      monitor = "DP-2",
      size = "1920 1080",
      center = true,
      fullscreen = true,
      opacity = "1.0 override 1.0 override",
      idle_inhibit = "focus",
    })

    -- ── Screenshot (Flameshot v13 + grim) ────────────────────────────────────
    -- Config em home/flameshot.nix. PROBLEMA multi-monitor: o grim captura os dois
    -- monitores (3840x1080), mas o overlay do editor nasce SÓ no monitor da origem
    -- → não cobre o desktop inteiro se o move/size não baterem com o bounding box.
    -- FIX (o clássico pré-v14): esticar a janela do overlay pelos DOIS monitores —
    -- float + move = canto do bounding box + size = soma das telas (3840x1080). Aí o
    -- overlay cobre tudo e a seleção funciona em qualquer tela. opacity/no_blur/
    -- no_shadow: o overlay é um frame congelado, não herda transparência/blur globais.
    -- Arranjo atual: HDMI-A-3 (TV) @ -1920x0 · DP-2 (principal) @ 0x0 → o canto
    -- superior-esquerdo do desktop é (-1920, 0), por isso o move é "-1920 0" (e NÃO
    -- "0 0", que deixava a TV de fora pós-swap dos conectores).
    --
    -- match por TÍTULO (não class): no v13/Wayland a janela do overlay tem class
    -- VAZIA e title exatamente "flameshot" (^...$ pra não casar o VS Code editando
    -- este arquivo). suppress_event=fullscreen: o overlay nasce fullscreen (cobre 1
    -- só monitor) — suprimir isso deixa o float+move+size assumirem.
    hl.window_rule({
      name  = "flameshot-overlay",
      match = { title = "^flameshot$" },

      no_anim        = true,
      float          = true,
      move           = "-1920 0",
      size           = "3840 1080",
      opacity        = "1.0 override 1.0 override",
      no_blur        = true,
      no_shadow      = true,
      rounding       = 0,
      suppress_event = "fullscreen",
    })

    -- Print ou SUPER+SHIFT+S (estilo Windows) → editor do flameshot cobrindo as
    -- duas telas; seleciona a região onde quiser e salva em ~/Pictures/Screenshots.
    hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"))

    -- ── Filtro de luz azul (hyprsunset) ──────────────────────────────────────
    -- O serviço (home/hyprsunset.nix) já troca a temperatura por horário sozinho;
    -- estes binds são override MANUAL pontual via IPC (`hyprctl hyprsunset`) — valem
    -- até o próximo perfil do schedule assumir. F9 liga/desliga o serviço inteiro.
    hl.bind(mainMod .. " + F9",         hl.dsp.exec_cmd("systemctl --user is-active --quiet hyprsunset && systemctl --user stop hyprsunset || systemctl --user start hyprsunset")) -- toggle serviço
    hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("hyprctl hyprsunset identity"))         -- filtro OFF (cores naturais)
    hl.bind(mainMod .. " + CTRL + F9",  hl.dsp.exec_cmd("hyprctl hyprsunset temperature 3000")) -- noite (quente)
    hl.bind(mainMod .. " + ALT + F9",   hl.dsp.exec_cmd("hyprctl hyprsunset temperature 2000")) -- madrugada (muito quente)
  '';

  # Sessão systemd do usuário. O LightDM lança o Hyprland "cru" (sem integração
  # systemd), então o graphical-session.target — que os serviços --user do desktop
  # (hyprsunset/hypridle/mako) usam como WantedBy — nunca era ativado, e nenhum
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
}
