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
  xdg.configFile."hypr/hyprland.lua".text = ''
    -- ── Monitores ────────────────────────────────────────────────────────────
    -- Nomes de conector confirmados via `hyprctl monitors` (Wayland/NVIDIA):
    --   DP-1     = LG ULTRAGEAR (1080p 144Hz) → à direita, monitor principal
    --   HDMI-A-1 = TV LG 1366x768             → à esquerda
    -- Campos: mode "LARGxALT@hz" (143.98 é o modo exato do LG), position "XxY".
    hl.monitor({ output = "DP-1",     mode = "1920x1080@143.98", position = "1366x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-1", mode = "preferred",        position = "0x0",    scale = 1 })
    hl.monitor({ output = "",         mode = "preferred",        position = "auto",   scale = "auto" })

    -- Workspace 1 (o principal/default) fica no LG.
    hl.workspace_rule({ workspace = "1", monitor = "DP-1", default = true })

    -- ── Programas ────────────────────────────────────────────────────────────
    local terminal = "kitty"
    local menu     = "wofi --show drun"

    -- ── Ambiente ─────────────────────────────────────────────────────────────
    hl.env("XCURSOR_SIZE", "24")
    hl.env("HYPRCURSOR_SIZE", "24")

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
    hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
    hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))          -- dwindle

    -- foco (setas)
    hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

    -- workspaces 1–10 (SUPER troca; SUPER+SHIFT move a janela)
    for i = 1, 10 do
      local key = i % 10  -- 10 mapeia pra tecla 0
      hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
      hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end

    -- mouse: mover / redimensionar janela
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
  '';
}
