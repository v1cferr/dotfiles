-- Input, ported from the Arch input.conf: an ABNT2 keyboard, a flat (unaccelerated) mouse and
-- numlock on. There is no real touchpad here, but it is left configured.
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
