-- Window rules, ported from the Arch window-rules.conf.
-- The Flameshot v14 rule is the subtle one: docs/notes/desktop/hypr.md

hl.window_rule({ match = { class = ".*" }, opacity = "0.98 0.96" })
-- clear-gradient: kitty's background_opacity (kitty.nix) is its ONLY reduction, so its text stays at
-- 100% instead of being dimmed again by the 0.98 above. The composite: docs/notes/desktop/theme.md
local C = dofile(os.getenv("HOME") .. "/.config/theme/hypr-colors.lua")
if C.glass == "clear-gradient" then
  hl.window_rule({ match = { class = "^(kitty)$" }, opacity = "1.0 override 1.0 override" })
end
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
-- League under Darling (darling-lol): the same crawl, measured at exactly 1 fps off screen. Its
-- X11 class is the process name, LeagueofLegends. docs/notes/desktop/hypr.md
hl.window_rule({ match = { class = "^(LeagueofLegends)$" }, render_unfocused = true })
-- Overwatch: opens tiled at 2550x1396 while it renders 2560x1440, and a frozen loop on a hidden
-- workspace stops answering the server ("lost connection"). Fullscreen plus the same keepalive.
hl.window_rule({ match = { class = "^(overwatch\\.exe)$" }, fullscreen = true, render_unfocused = true })
-- Any FULLSCREEN game keeps the cursor on its own monitor: Wine/Bottles (`*.exe`), Proton
-- (`steam_app_N`), gamescope and Darling's League. Windowed and the launchers stay free, the LG
-- is one flick away.
hl.window_rule({
  match = { class = "^(.*\\.exe|steam_app_\\d+|gamescope|LeagueofLegends)$", fullscreen = true },
  confine_pointer = true,
})

-- The Gaming profile while ANY game window is open, gamemoderun or not: the same set as the rule
-- above, as a Lua test, since window queries match a class exactly. docs/notes/hardware/power.md
local function is_game(class)
  class = (class or ""):lower()
  if class == "battle.net.exe" then
    return false -- a launcher left open would hold Gaming for hours
  end
  return class:match("%.exe$") ~= nil or class:match("^steam_app_%d+$") ~= nil or class == "gamescope"
    or class == "leagueoflegends"
end
local gaming = nil -- unknown after a reload, so the first check always says it
local function sync_game_hold()
  local any = false
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and is_game(w.class) then
      any = true
      break
    end
  end
  if any ~= gaming then
    gaming = any
    hl.exec_cmd("systemctl --user " .. (any and "start" or "stop") .. " game-performance.service")
  end
end
for _, event in ipairs({ "window.open", "window.class", "window.destroy" }) do
  hl.on(event, sync_game_hold)
end
sync_game_hold()

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

-- Vicinae's layer surface: a fade and NO movement (150 ms in, 100 ms out). Pinned here so a later
-- `layers` style cannot zoom the launcher; the measurements: docs/notes/desktop/motion.md
hl.layer_rule({ match = { namespace = "^vicinae$" }, animation = "fade" })
