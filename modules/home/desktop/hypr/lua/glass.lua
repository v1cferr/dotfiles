-- HyprGlass in the glass profile (my.theme.glass), ONLY when Nix names the plugin. Loaded
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

-- The profile (my.theme.glass). clear-gradient: a lighter tint, more brightness and LESS blur, so the
-- shapes behind read; perceptible: the baseline. Only these numbers differ: docs/notes/desktop/hyprglass.md
local V = ({
  ["clear-gradient"] = { tint = "33", tintPanel = "4d", brightness = 0.95, blur = 0.9, blurUi = 1.2, blurPanel = 1.6, refraction = 0.25 },
})[C.glass] or { tint = "55", tintPanel = "80", brightness = 0.85, blur = 1.2, blurUi = 1.6, blurPanel = 2.0, refraction = 0.3 }
local solid = C.glass == "solid" -- opaque surfaces: nothing behind them to glass

hg.config({
  -- Every window, the plugin skipping what is opaque; true fullscreen and games opt out below.
  enabled = not solid,
  default_theme = "dark",
  default_preset = "window",
  -- The shell's surfaces: glass where they are at least half opaque, never their transparent gaps.
  layers = { enabled = not solid, mask_threshold = 0.5 },
})

-- What is behind reads as shapes and colors, the text in front stays crisp. Built on upstream's
-- `subtle`, with the refraction pushed to the rim and nothing iridescent; xray and self sampling off.
hg.preset("window", {
  inherits = "subtle",
  xray = 0, -- the windows behind stay visible: that IS the depth
  self_sample = 0.0,
  blur_strength = V.blur,
  refraction_strength = V.refraction,
  refraction_spread = 0.2, -- a rim, the center flat, so no text sits on a distortion
  lens_distortion = 0.0,
  chromatic_aberration = 0.0,
  specular_strength = 0.15,
  fresnel_strength = 0.2,
  tint_color = tint(V.tint),
  dark = { brightness = V.brightness, contrast = 0.95 },
})
-- The bar and the band: more blur and less refraction, since text sits across their whole surface.
hg.preset("ui", {
  inherits = "window",
  blur_strength = V.blurUi,
  refraction_strength = 0.12,
  edge_thickness = 0.02,
})
-- Panels and toasts are read the longest: the most blur and the darkest tint.
hg.preset("panel", {
  inherits = "ui",
  blur_strength = V.blurPanel,
  tint_color = tint(V.tintPanel),
})

hg.layer("qs-bar", { preset = "ui" })
hg.layer("qs-dash", { preset = "ui" })
hg.layer("qs-panel", { preset = "panel" })
hg.layer("qs-center", { preset = "panel" })

-- Where glass never goes: the games, Picture-in-Picture and Flameshot's frozen overlay (rules.lua
-- keeps their other rules). The tag wins over the global switch.
hl.window_rule({ match = { class = "^(hearthstone\\.exe|overwatch\\.exe|steam_app_.*)$" }, tag = "+hyprglass_disabled" })
hl.window_rule({ match = { title = "^(Picture-in-Picture|flameshot)$" }, tag = "+hyprglass_disabled" })

-- Nor on a TRUE fullscreen window (state 2), tagged on the way in and untagged on the way out. Not a
-- rule: `fullscreen = true` also matches the maximized state a lone scrolling column has at map, and
-- a rule's tag outlived the fullscreen (both measured on 0.56.2). Removing the static tag leaves a
-- game rule's dynamic one alone.
hl.on("window.fullscreen", function(w)
  local sign = w.fullscreen == 2 and "+" or "-"
  hl.dispatch(hl.dsp.window.tag({ tag = sign .. "hyprglass_disabled", window = "address:" .. w.address }))
end)
