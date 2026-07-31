-- ── Aparência: geral + decoração + animações ───────────────────────────────
-- Portado do look-and-feel.conf do Arch (Tokyo Night), adaptado à API Lua 0.55.

-- Paleta vinda do Nix (my.theme): tabela gerada por home/desktop/palette.nix. Hexes SEM
-- '#'; as bordas/sombra abaixo montam rgba(<hex><alpha>). Trocar o tema recolore tudo.
local C = dofile(os.getenv("HOME") .. "/.config/theme/hypr-colors.lua")

-- general: gaps/borda finos + borda com GRADIENTE (azul→magenta 45°). Na API Lua o
-- gradiente é a tabela { colors={...}, angle=N } — a string hyprlang não cola.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 4,
    border_size = 1,
    ["col.active_border"]   = { colors = { "rgba(" .. C.blue .. "55)", "rgba(" .. C.magenta .. "44)" }, angle = 45 },
    ["col.inactive_border"] = "rgba(" .. C.border .. "44)",
    resize_on_border = false, -- não redimensiona clicando na borda/gap
    allow_tearing = false,    -- sem tearing (ver wiki antes de ligar)
    layout = "scrolling",     -- fita infinita em TODAS as ws (nativo 0.55); binds em keybinds.lua
  },
  -- decoração: cantos arredondados + blur + sombra. A opacidade das janelas fica
  -- na window_rule global (rules.lua): 0.98 ativa / 0.96 inativa.
  decoration = {
    rounding = 10,
    shadow = {
      enabled = true,
      range = 6,
      render_power = 3,
      color = "rgba(" .. C.shadow .. "ee)",
    },
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      noise = 0.01,
      contrast = 0.9,
      brightness = 0.8,
      new_optimizations = true,
      vibrancy = 0.2,
    },
  },
  -- Sem bloco `scrolling`: os 7 defaults já são o que se quer (column_width 0.5 = 2 colunas
  -- de 960px em 1080p, fullscreen_on_one_column, follow_focus, wrap_focus, direction right,
  -- focus_fit_method, explicit_column_widths) — conferido com `hyprctl getoption`.
  -- O bloco `dwindle` saiu junto com o layout: nenhuma ws usa dwindle mais.
  misc = {
    force_default_wallpaper = 0,  -- sem o wallpaper anime default
    disable_hyprland_logo = true, -- sem o logo de fundo (usamos wallpaper próprio)
    -- VRR (G-Sync) só em jogos fullscreen. O LG UltraGear é G-Sync Compatible; na
    -- Arc (xe) o congelamento que a NVIDIA dava no lockscreen NÃO reproduz (por isso
    -- o vrr=1 sempre-ligado foi vetado no Arch — histórico em lockscreen.nix). 2 é seguro.
    vrr = 2,
    -- Rede de segurança contra lockout: se o hyprlock morrer no teardown (ex.: ao
    -- acordar do dpms), relançar `hyprlock` de um TTY reata a sessão travada em vez
    -- de recusar — evita o "sudo reboot" pra sair de uma tela de bloqueio órfã.
    allow_session_lock_restore = true,
  },
})

-- ── Animações ───────────────────────────────────────────────────────────────
-- Beziers custom via hl.curve (o antigo `bezier=` do hyprlang). "default" e
-- "linear" são embutidos do Hyprland; os quatro abaixo definimos nós.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 }   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 }   } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 }    } })

hl.config({ animations = { enabled = true } })

-- leaf=nome da animação, speed=duração (menor=mais rápido), bezier=curva, style=variação.
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
