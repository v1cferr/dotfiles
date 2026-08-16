-- Window rules, ported from the Arch window-rules.conf.
-- The Flameshot v14 rule is the subtle one: docs/notes/desktop/hypr.md

-- Nix data with a SELF-CONTAINED FALLBACK: a bare dofile would BLOW UP and abort the config,
-- and "autostart" loads later, so the session would come up with no services at all.
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-2", secondary = "HDMI-A-3" } end

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
-- Ascension (a private WoW through Wine): floating, centered on the LG, opaque, no idle-lock.
hl.window_rule({
  match = { class = "^(ascension\\.exe)$" },
  float = true,
  monitor = M.primary,
  size = "1920 1080",
  center = true,
  fullscreen = true,
  opacity = "1.0 override 1.0 override",
  idle_inhibit = "focus",
})

-- Flameshot v14: the old -1920/3840 stretch BREAKS it, since v14 opens a PICKER first. Only
-- float plus center, matched by TITLE (the class is empty). Every flag: docs/notes/desktop/hypr.md
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
  suppress_event = "fullscreen",
})
