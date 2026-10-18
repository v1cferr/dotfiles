-- Perceptible Glass through HyprGlass, ONLY when Nix names the plugin (my.hypr.hyprglass). Loaded
-- before appearance.lua, which keeps the native blur off what this takes: docs/notes/desktop/hyprglass.md
local home = os.getenv("HOME")
local ok, P = pcall(dofile, home .. "/.config/theme/plugins.lua")
local C = dofile(home .. "/.config/theme/hypr-colors.lua")

-- EVERY pass declares it: Hyprland's plugin list is declarative, a pass that omits it unloads it, and
-- a "load once" guard made load/unload alternate, one reload per pass, until the stack overflowed.
if ok and P and P.hyprglass then
  hl.plugin.load(P.hyprglass)
end
if not hl.plugin.hyprglass then
  return -- off, missing or paused: the native blur in appearance.lua stays in charge
end

local hg = hl.plugin.hyprglass
-- The tint is the palette's bg at about a third: Tokyo Night's own dark, never a gray of the plugin's.
local tint = function(alpha) return tonumber(C.bg .. alpha, 16) end

hg.config({
  -- Windows get glass by TAG only (below): a browser or an editor at 0.98 opacity gains nothing.
  enabled = false,
  default_theme = "dark",
  default_preset = "perceptible",
  -- The shell's surfaces: glass where they are at least half opaque, never their transparent gaps.
  layers = { enabled = true, mask_threshold = 0.5 },
})

-- Perceptible: what is behind reads as shapes and colors, the text in front stays crisp. Built on
-- upstream's `subtle`, with the refraction pushed to the rim and nothing iridescent.
hg.preset("perceptible", {
  inherits = "subtle",
  xray = 0, -- the windows behind stay visible: that IS the depth
  self_sample = 0.0,
  blur_strength = 1.2,
  refraction_strength = 0.3,
  refraction_spread = 0.2, -- a rim, the center flat, so no text sits on a distortion
  lens_distortion = 0.0,
  chromatic_aberration = 0.0,
  specular_strength = 0.15,
  fresnel_strength = 0.2,
  tint_color = tint("55"),
  dark = { brightness = 0.85, contrast = 0.95 },
})
-- The bar and the band: more blur and less refraction, since text sits across their whole surface.
hg.preset("perceptible_ui", {
  inherits = "perceptible",
  blur_strength = 1.6,
  refraction_strength = 0.12,
  edge_thickness = 0.02,
})
-- Panels and toasts are read the longest: the most blur and the darkest tint.
hg.preset("perceptible_panel", {
  inherits = "perceptible_ui",
  blur_strength = 2.0,
  tint_color = tint("80"),
})

hg.layer("qs-bar", { preset = "perceptible_ui" })
hg.layer("qs-dash", { preset = "perceptible_ui" })
hg.layer("qs-panel", { preset = "perceptible_panel" })

-- Where glass goes: the terminal and floating windows. Where it never does: the games,
-- Picture-in-Picture and Flameshot's frozen overlay (rules.lua keeps their other rules). No rule on
-- fullscreen: the scrolling layout counts a lone column as fullscreen, so it matched nearly every
-- window; opaque fullscreen content (a game, a video) is skipped by the plugin itself anyway.
hl.window_rule({ match = { class = "^(kitty)$" }, tag = "+hyprglass_enabled" })
hl.window_rule({ match = { float = 1 }, tag = "+hyprglass_enabled" })
hl.window_rule({ match = { class = "^(hearthstone\\.exe|overwatch\\.exe|steam_app_.*)$" }, tag = "+hyprglass_disabled" })
hl.window_rule({ match = { title = "^(Picture-in-Picture|flameshot)$" }, tag = "+hyprglass_disabled" })
