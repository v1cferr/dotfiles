-- Appearance: general plus decoration plus animations, ported from the Arch look-and-feel.conf.
-- The gradient border must be a TABLE in the Lua API; the rest: docs/notes/desktop/hypr.md

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
    -- vrr=1: VRR always on, windowed games included. The lockscreen freeze that vetoed it under
    -- NVIDIA does NOT reproduce on the Arc's xe. See the notes.
    vrr = 1,
    -- A safety net against a lockout: relaunching hyprlock from a TTY REATTACHES the locked
    -- session instead of refusing, so there is no `sudo reboot` to escape an orphaned lock.
    allow_session_lock_restore = true,
    -- The ceiling for the `render_unfocused` windows in rules.lua (a game on a hidden workspace).
    -- 30 and not the default 15 because at 15 the measurement came out JITTERY (8 to 18 fps) and
    -- the game loop drives the AUDIO too; at 30 it holds steady. It only costs while one exists.
    render_unfocused_fps = 30,
  },
})

-- The shell's glass (my.theme.glass): blur under Quickshell's named surfaces, and ignore_alpha keeps
-- it off their transparent margins and gaps. `solid` paints opaque, so no blur is paid for.
if (C.glass or "soft") ~= "solid" then
  hl.layer_rule({ match = { namespace = "^qs-(bar|dash|panel)$" }, blur = true, ignore_alpha = 0.5 })
end

-- ── Animations ──────────────────────────────────────────────────────────────
-- Smooth and Subtle: a spring for what MOVES, a short ease-out for opacity and color, exits
-- shorter than entrances. Every value and what it replaced: docs/notes/desktop/motion.md
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 },  { 0.32, 1 }   } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1.0 } } })
-- Near-critical (zeta 0.93): 90% at ~130 ms, settled by ~310 ms, sub-pixel overshoot. A spring
-- IGNORES `speed`. The key is `dampening` on 0.56; main renamed it and still reads the old one.
hl.curve("settle", { type = "spring", mass = 1, stiffness = 700, dampening = 49 })

-- my.theme.motion = "off" drops them all; the default fallback covers a file not rebuilt yet.
hl.config({ animations = { enabled = (C.motion or "subtle") ~= "off" } })

-- leaf = the name, speed = deciseconds (1 = 100 ms), bezier/spring = the curve, style = the variation.
hl.animation({ leaf = "global",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 3,   spring = "settle" }) -- windowsMove inherits it
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 2.2, bezier = "easeOutQuint", style = "popin 97%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 1.3, bezier = "almostLinear", style = "popin 97%" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2,   bezier = "almostLinear" }) -- focus, dim, shadow, popups
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 1.8, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 1.2, bezier = "almostLinear" })
hl.animation({ leaf = "border",           enabled = true, speed = 2,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layers",           enabled = true, speed = 1.6, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 1,   bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 1.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 1,   bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 2,   spring = "settle", style = "slidefade 8%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 1.8, bezier = "easeOutQuint", style = "fade" })
