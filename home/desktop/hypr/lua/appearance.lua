-- Appearance: general plus decoration plus animations, ported from the Arch look-and-feel.conf.
-- The gradient border must be a TABLE in the Lua API; the rest: docs/notes/hypr.md

-- The palette comes from Nix (my.theme), hexes WITHOUT '#'; the rgba() is assembled below.
local C = dofile(os.getenv("HOME") .. "/.config/theme/hypr-colors.lua")

-- general: thin gaps/border plus a GRADIENT border. In the Lua API the gradient is a table
-- { colors={...}, angle=N }; the hyprlang string does not stick.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 4,
    border_size = 1,
    ["col.active_border"]   = { colors = { "rgba(" .. C.blue .. "55)", "rgba(" .. C.magenta .. "44)" }, angle = 45 },
    ["col.inactive_border"] = "rgba(" .. C.border .. "44)",
    resize_on_border = false, -- it does not resize by clicking the border/gap
    allow_tearing = false,    -- no tearing (read the wiki before turning it on)
    layout = "scrolling",     -- an infinite tape on ALL the workspaces (native in 0.55); the binds are in keybinds.lua
  },
  -- decoration. The windows' opacity is the global window_rule in rules.lua (0.98/0.96).
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
  -- The tape: 1 window per screen. The ONLY value away from the default; the other 6 scrolling
  -- settings already are what we want. The dwindle block left with the layout.
  scrolling = {
    column_width = 1.0,
  },
  misc = {
    force_default_wallpaper = 0,  -- without the default anime wallpaper
    disable_hyprland_logo = true, -- without the background logo (we use our own wallpaper)
    -- vrr=2: G-Sync in fullscreen games only. On the Arc's xe the lockscreen freeze NVIDIA gave
    -- does NOT reproduce, which is why always-on vrr=1 was vetoed on Arch. See the notes.
    vrr = 2,
    -- A safety net against a lockout: relaunching hyprlock from a TTY REATTACHES the locked
    -- session instead of refusing, so there is no `sudo reboot` to escape an orphaned lock.
    allow_session_lock_restore = true,
  },
})

-- ── Animations ──────────────────────────────────────────────────────────────
-- Animations. Custom beziers through hl.curve; "default" and "linear" are built in.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 }   } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 }   } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 }    } })

hl.config({ animations = { enabled = true } })

-- leaf = the name, speed = the duration (lower is faster), bezier = the curve, style = the
-- variation.
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
