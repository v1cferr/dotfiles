-- Input, ported from the Arch input.conf: a flat (unaccelerated) mouse and numlock on. The
-- keyboard layout and the touchpad are the HOST's (my.keyboard, my.touchpad).

-- Nix data with a SELF-CONTAINED FALLBACK, for the same reason as in monitors.lua.
local ok_K, K = pcall(dofile, os.getenv("HOME") .. "/.config/theme/keyboard.lua")
if not ok_K or type(K) ~= "table" then K = { layout = "br", variant = "abnt2" } end
local ok_T, T = pcall(dofile, os.getenv("HOME") .. "/.config/theme/touchpad.lua")
if not ok_T or type(T) ~= "table" then T = { natural_scroll = false, tap_to_click = true } end

hl.config({
  input = {
    kb_layout = K.layout,
    kb_variant = K.variant,
    numlock_by_default = true, -- the numpad on at boot (a desktop)
    follow_mouse = 1,          -- the mouse always changes the focus
    sensitivity = 0,           -- no modification (-1.0..1.0)
    accel_profile = "flat",    -- no acceleration (precise for games/work)
    natural_scroll = false,    -- traditional scrolling (not inverted)
    scroll_factor = 1.0,
    touchpad = {
      natural_scroll = T.natural_scroll,
      ["tap-to-click"] = T.tap_to_click,
    },
  },
})
