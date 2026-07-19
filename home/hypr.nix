# CONFIG do Hyprland em Lua (~/.config/hypr/hyprland.lua), declarada. O compositor
# e a sessão vêm do system/ (programs.hyprland.enable); aqui é SÓ o arquivo de
# config (regra da pasta: home/ configura, não instala).
#
# Formato Lua (Hyprland 0.55+): substitui o antigo hyprland.conf (hyprlang), que
# está deprecado. `hl` é um objeto global injetado pelo Hyprland. Se hyprland.lua
# existir, ele é carregado no lugar do .conf. Docs: https://wiki.hypr.land
#
# Base enxuta e usável (keybinds equivalentes ao exemplo default) já com ABNT2 e
# os monitores certos. Nota: vindo do /nix/store (read-only), mudanças exigem
# rebuild; na fase de iteração rápida, trocar por mkOutOfStoreSymlink p/ hot-reload.
{ ... }:

{
  # ── Ociosidade: apaga os monitores após 5 min (hypridle) ───────────────────
  # hypridle (pacote no system/) escuta o tempo ocioso do Hyprland. O único
  # listener apaga AMBOS os monitores via DPMS (hyprctl dispatch dpms off pega
  # todas as saídas de uma vez) e religa ao mexer mouse/teclado. NÃO suspende —
  # coerente com o systemd.targets.sleep desligado no system/ (desktop remoto).
  # Monitor externo não tem backlight controlável por software, então "escurecer"
  # aqui = apagar (standby), não reduzir brilho.
  #
  # Formato hyprlang (.conf), NÃO Lua: a lua-ificação do 0.55 é só do COMPOSITOR
  # (hyprland.lua). Os satélites (hypridle/hyprlock/hyprpaper) ainda são .conf —
  # cada daemon migra no seu tempo; não existe hypridle.lua hoje. O único pedaço
  # que é do compositor — subir o daemon — vai em Lua no autostart mais abaixo.
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
      ignore_dbus_inhibit = false
    }

    listener {
      timeout    = 300                        # 5 min ocioso
      on-timeout = hyprctl dispatch dpms off  # apaga os dois monitores
      on-resume  = hyprctl dispatch dpms on   # religa ao voltar
    }
  '';

  xdg.configFile."hypr/hyprland.lua".text = ''
    -- ── Monitores ────────────────────────────────────────────────────────────
    -- Nomes de conector confirmados via `hyprctl monitors` (Wayland/NVIDIA):
    --   DP-1     = LG ULTRAGEAR (1080p 144Hz) → à direita (em 1920x0), principal
    --   HDMI-A-1 = TV LG (Full HD; a EDID default reporta 1366x768) → à esquerda
    -- Campos: mode "LARGxALT@hz" (143.98 é o modo exato do LG), position "XxY".
    hl.monitor({ output = "DP-1",     mode = "1920x1080@143.98", position = "1920x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",     position = "0x0",    scale = 1 })
    hl.monitor({ output = "",         mode = "preferred",        position = "auto",   scale = "auto" })

    -- 4 workspaces por monitor: 1–4 no LG (DP-1, principal), 5–8 na TV (HDMI-A-1).
    -- default:true = a workspace que abre em cada monitor no boot da sessão.
    hl.workspace_rule({ workspace = "1", monitor = "DP-1",     default = true })
    hl.workspace_rule({ workspace = "2", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "3", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "4", monitor = "DP-1" })
    hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", default = true })
    hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1" })
    hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
    hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1" })

    -- ── Programas ────────────────────────────────────────────────────────────
    local terminal = "kitty"
    local menu     = "wofi --show drun"

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
    -- hyprland.start dispara UMA vez no boot da sessão (não em reload) → sobe o
    -- hypridle, que lê ~/.config/hypr/hypridle.conf e apaga os monitores no ocioso.
    hl.on("hyprland.start", function()
      hl.exec_cmd("hypridle")
      hl.exec_cmd("waybar")
      -- watcher do clipboard: escuta cada cópia e grava no histórico do cliphist.
      -- Sem isto o cliphist fica vazio (é o daemon que popula o banco).
      hl.exec_cmd("wl-paste --watch cliphist store")
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

    -- ── Keybinds (equivalentes ao default) ───────────────────────────────────
    local mainMod = "SUPER"

    hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))              -- terminal
    hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))                  -- launcher
    hl.bind(mainMod .. " + C", hl.dsp.window.close())                 -- fechar
    hl.bind(mainMod .. " + M", hl.dsp.exit())                         -- sair do Hyprland
    hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
    -- clipboard: abre o histórico do cliphist no wofi; a escolha volta pro clipboard.
    -- (roda via sh -c do exec → o pipe funciona; cole normal com Ctrl+V depois)
    hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))
    hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
    hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))          -- dwindle

    -- foco (setas)
    hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

    -- workspaces 1–8 (SUPER troca; SUPER+SHIFT move a janela).
    -- SUPER+1..4 → LG (DP-1) · SUPER+5..8 → TV (HDMI-A-1). O foco segue o monitor
    -- da workspace (pelas workspace_rule acima).
    for i = 1, 8 do
      hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
      hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
    end

    -- mouse: mover / redimensionar janela
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

    -- ── Screenshot (Flameshot v13 + grim) ────────────────────────────────────
    -- Config em home/flameshot.nix. PROBLEMA multi-monitor: o grim captura os dois
    -- monitores (3840x1080), mas o overlay do editor nasce SÓ no monitor da origem
    -- (HDMI @ 0,0) → não dava pra selecionar no DP-1 (principal @ 1920,0).
    -- FIX (o clássico pré-v14): esticar a janela do overlay pelos DOIS monitores —
    -- float + move 0,0 + size = soma das telas (3840x1080). Aí o overlay cobre tudo
    -- e a seleção funciona em qualquer tela. opacity/no_blur/no_shadow: o overlay é
    -- um frame congelado, não pode herdar transparência/blur globais.
    -- (Tamanho fixo pro arranjo desta máquina: 2x 1080p lado a lado.)
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
      move           = "0 0",
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
  '';
}
