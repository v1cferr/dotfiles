-- ── Input (keyboard/mouse) ──────────────────────────────────────────────────
-- Ported from the Arch input.conf. An ABNT2 keyboard; the mouse with no acceleration (flat) and
-- numlock on (a desktop). There is no real touchpad, but it is left configured.
hl.config({
  input = {
    kb_layout = "br",
    kb_variant = "abnt2",
    numlock_by_default = true, -- the numpad on at boot (a desktop)
    follow_mouse = 1,          -- the mouse always changes the focus
    sensitivity = 0,           -- no modification (-1.0..1.0)
    accel_profile = "flat",    -- no acceleration (precise for games/work)
    natural_scroll = false,    -- traditional scrolling (not inverted)
    scroll_factor = 1.0,
    touchpad = {
      natural_scroll = false,
    },
  },
})
