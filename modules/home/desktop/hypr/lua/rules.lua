-- Window rules, ported from the Arch window-rules.conf.
-- The Flameshot v14 rule is the subtle one: docs/notes/desktop/hypr.md

hl.window_rule({ match = { class = ".*" }, opacity = "0.98 0.96" })
-- A subtle transparency on everything (0.98 active / 0.96 inactive), then maximize suppressed,
-- which behaves better under tiling.
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
-- The XWayland drag fix: classless floating windows that steal focus.
hl.window_rule({
  match = { class = "^$", title = "^$", xwayland = 1, float = 1, fullscreen = 0 },
  suppress_event = "activate activatefocus",
})
-- Picture-in-Picture (a detached video) always 100% opaque.
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, opacity = "1.0" })
-- Hearthstone: off screen the game CRAWLS to 1 fps and its render AND audio only catch up when the
-- workspace comes back, because an invisible surface gets no frame callback. render_unfocused keeps
-- it drawing at misc.render_unfocused_fps. Measured: docs/notes/desktop/hypr.md
hl.window_rule({ match = { class = "^(hearthstone\\.exe)$" }, render_unfocused = true })

-- Flameshot v14: the overlay ASKS for fullscreen and suppressing it left it 17 px low, under the
-- bar's reserved area. float plus center is for the PICKER only. Every flag: docs/notes/desktop/hypr.md
hl.window_rule({
  name = "flameshot-v14-overlay",
  match = { title = "^flameshot$" },

  no_anim = true,
  float = true,
  center = true,
  pin = false,
  opacity = "1.0 override 1.0 override",
  no_blur = true,
  no_shadow = true,
  rounding = 0,
})
