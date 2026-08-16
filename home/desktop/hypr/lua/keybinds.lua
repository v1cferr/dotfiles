-- Keybinds (parity with the Arch/Kingston). The comments here GENERATE the SUPER+H cheatsheet.
-- The monitor pcall fallback is load-order critical; every why: docs/notes/keybinds.md
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-2", secondary = "HDMI-A-3" } end

local mainMod = "SUPER"

-- The programs the binds below call (tools adapted to NixOS).
local terminal       = "kitty"            -- SUPER+RETURN
local terminalWithAi = "kitty claude"     -- SUPER+BACKSPACE (Claude Code in the terminal)
local launcherApps   = "rofi -show drun -theme launcher" -- SUPER+Q (.desktop apps; icons plus recency)
local launcherRun    = "rofi -show run -theme launcher"  -- SUPER+R (binaries on the PATH)
local fileManager    = "dolphin"          -- SUPER+E [it used to be thunar]
local sound          = "pavucontrol"      -- SUPER+S (the audio mixer)
local bluetooth      = "blueman-manager"  -- SUPER+B

-- The main apps and actions
hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(launcherApps))                 -- launcher (apps)
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(launcherRun))                  -- launcher (run)
hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(terminal))                     -- terminal
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(terminalWithAi))               -- terminal with AI (Claude Code)
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))                  -- files (Dolphin)
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd(sound))                        -- audio mixer
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(bluetooth))                    -- bluetooth
hl.bind(mainMod .. " + C",         hl.dsp.window.close())                         -- close the window
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))    -- float
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))  -- fullscreen
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())                        -- pseudo (a dwindle thing; a no-op on scrolling, but it answers ok and raises no toast)
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl reload"))             -- reload the config
-- The cheatsheet, generated from THIS file at runtime. H and not "/" for the Moonlight reason
-- below.
hl.bind(mainMod .. " + H",         hl.dsp.exec_cmd("keybinds-cheatsheet"))        -- help: the shortcut list
-- lock: loginctl to logind to hypridle's lock_cmd; it never duplicates hyprlock.
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))      -- lock the screen

-- The "/" key over remote access: Moonlight does not send the ABNT2 "/ ?", so ScrollLock is
-- remapped. `code:97` and NOT `slash`, because of xkb modifier levels: docs/notes/keybinds.md
hl.bind("Scroll_Lock",         hl.dsp.send_shortcut({ mods = 0,       key = "code:97", window = "activewindow" }))  -- "/"
hl.bind("SHIFT + Scroll_Lock", hl.dsp.send_shortcut({ mods = "SHIFT", key = "code:97", window = "activewindow" }))  -- "?" (Shift+/)

-- clipboard: cliphist's history in rofi, with an image thumbnail and an icon per file type.
-- The script and the theme are in home/desktop/clipboard.nix.
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("clipboard-menu"))

-- VPN: SUPER+N = UFSCar (GlobalProtect), SHIFT+N = FAI (nxBender), CTRL+N disconnects all.
-- On-demand systemd services (system/net/vpn.nix); the `vpn` CLI needs no password (polkit).
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("vpn connect ufscar"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("vpn connect fai"))
hl.bind(mainMod .. " + CTRL + N",  hl.dsp.exec_cmd("vpn disconnect all"))

-- Restarting Quickshell: rarely needed, since the QML hot-reloads; useful when it hangs.
hl.bind(mainMod .. " + ESCAPE",    hl.dsp.exec_cmd("qs-restart")) -- restart Quickshell (a Repeater delegate does not pick up the hot-reload)

-- Minimize: it sends the OTHER windows of the workspace to special:minimized (a toggle).
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("minimize-others"))
hl.bind(mainMod .. " + CTRL + M",  hl.dsp.workspace.toggle_special("minimized"))  -- open/close the special

-- Focus between windows (the arrows)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- The scrolling layout's tape (global; see appearance.lua). NO GUARD, because ALL workspaces
-- are scrolling: if any goes back to dwindle, read docs/notes/keybinds.md FIRST.
hl.bind(mainMod .. " + comma",          hl.dsp.layout("move -col"))       -- tape left, 1 column
hl.bind(mainMod .. " + period",         hl.dsp.layout("move +col"))       -- tape right, 1 column
-- The MX Master's thumbwheel = SUPER plus the horizontal wheel; logiops no longer diverts it,
-- and the 300ms scroll_event_delay stopped mattering for a COLUMN jump. See the notes.
hl.bind(mainMod .. " + mouse_left",     hl.dsp.layout("move -col"))       -- thumbwheel left
hl.bind(mainMod .. " + mouse_right",    hl.dsp.layout("move +col"))       -- thumbwheel right
-- The VERTICAL wheel moves along the tape too (it used to switch workspaces, never used).
-- The direction was set BY HAND: scrolling DOWN advances toward the side you use most.
hl.bind(mainMod .. " + mouse_down",     hl.dsp.layout("move -col"))       -- wheel down = forward
hl.bind(mainMod .. " + mouse_up",       hl.dsp.layout("move +col"))       -- wheel up = back
-- Reordering and resizing columns. swapcol moves the WHOLE COLUMN and wraps; to move one
-- window out of a stack, expel (SUPER+O) first.
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.layout("swapcol l"))       -- swap with the column on the left
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.layout("swapcol r"))       -- swap with the column on the right
hl.bind(mainMod .. " + ALT + comma",    hl.dsp.layout("colresize -conf")) -- cycle the width down, ONLY the active column
hl.bind(mainMod .. " + ALT + period",   hl.dsp.layout("colresize +conf")) -- cycle the width up, ONLY the active column
-- View modes: they change the WHOLE tape (ALT+,/. above is only the active column).
-- `fit all` is not `colresize all N`, which does not bring the view along: the notes.
hl.bind(mainMod .. " + CTRL + G",       hl.dsp.layout("fit all"))           -- SEE EVERYTHING: it squeezes the whole tape onto the screen
hl.bind(mainMod .. " + CTRL + period",  hl.dsp.layout("colresize all 1.0")) -- FOCUS: everything at 100% (1 window per screen)
hl.bind(mainMod .. " + CTRL + comma",   hl.dsp.layout("colresize all 0.5")) -- everything at 50% (2 side by side, fixed)
-- Stacking and unstacking windows inside the column.
hl.bind(mainMod .. " + I",              hl.dsp.layout("consume"))         -- pull the window into the previous column
hl.bind(mainMod .. " + O",              hl.dsp.layout("expel"))           -- expel the window into a column of its own
-- `fit active` and NOT `fit_into_view`: 0.55.4 answers "no such layoutmsg". Every layout
-- message requires a FOCUSED window.
hl.bind(mainMod .. " + G",              hl.dsp.layout("fit active"))      -- recenter the active column
hl.bind(mainMod .. " + SHIFT + G",      hl.dsp.layout("fit expand"))      -- expand the window into the free space

-- Focus by monitor: F1 = the LG (main), F2 = the TV (secondary). The names: my.monitors.
hl.bind(mainMod .. " + F1", hl.dsp.focus({ monitor = M.primary }))
hl.bind(mainMod .. " + F2", hl.dsp.focus({ monitor = M.secondary }))

-- Turning the TV on and off in Hyprland, by hand. Workspaces 5-8 come back to the LG.
-- It is needed because the TV keeps the HDMI link alive while off: docs/notes/hypr.md
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("monitor-toggle"))

-- Workspaces 1 to 8 (SUPER switches; SUPER+SHIFT moves the window). 1-4 on the LG, 5-8 on the TV.
for i = 1, 8 do
  hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Relative navigation (the previous/next workspace).
-- KEYBOARD ONLY: the wheel left here and went to the tape.
hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

-- Moving the active window between monitors: CTRL+left to the TV, CTRL+right to the LG.
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ monitor = M.secondary }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ monitor = M.primary }))

-- Mouse: move / resize the window. The RESIZE is what puts one window beside another, since
-- scrolling implements a real resize-drag; the DRAG only stacks. See the notes.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- "Arrange side by side", in one click. On scrolling EVERY sideways move STACKS (hardcoded in
-- CScrollingAlgorithm), so this UNDOES instead: expel plus fit all. Why a lambda: the notes.
local expelCol, fitAll = hl.dsp.layout("expel"), hl.dsp.layout("fit all")
hl.bind(mainMod .. " + mouse:274", function()                                     -- middle click: unstack plus show everything
  hl.dispatch(expelCol)
  return hl.dispatch(fitAll)
end)

-- Media / volume / brightness keys.
-- locked = it works with the screen locked; repeating = it repeats while held.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- volume up (capped at 100%)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- volume down
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })  -- mute the output
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })  -- mute the microphone
-- play/pause/next/prev through playerctl (locked only; repeating makes no sense).
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- brightness = hyprsunset's gamma (a desktop with no backlight); the OSD is Quickshell's own.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightness-osd up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightness-osd down"), { locked = true, repeating = true })
-- Brightness (gamma): SHIFT+Vol up = brighter, SHIFT+Vol down = darker, SUPER+SHIFT+B resets.
-- NOT SHIFT+0, which consumed the keystroke and made ")" untypable on ABNT2.
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("brightness-osd up"),    { locked = true, repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("brightness-osd down"),  { locked = true, repeating = true })
hl.bind(mainMod .. " + SHIFT + B",      hl.dsp.exec_cmd("brightness-osd reset"), { locked = true })

-- Screenshot (Flameshot v14). Print = the native flow; SUPER+SHIFT+S = the KEYBOARD flow, a
-- submap where 1/2 pick the monitor and Esc cancels. See docs/notes/flameshot.md
hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot-screenshot"))

hl.define_submap("screenshot", function()
  -- positional: 1 = the LEFT screen (the TV), 2 = the RIGHT screen (the main LG).
  hl.bind("1",      hl.dsp.exec_cmd("flameshot-pick " .. M.secondary)) -- secondary (the TV, on the left)
  hl.bind("2",      hl.dsp.exec_cmd("flameshot-pick " .. M.primary))     -- main (the LG, on the right)
  hl.bind("escape", hl.dsp.exec_cmd("flameshot-cancel"))        -- cancel plus leave the submap
end)

-- The blue light filter. The service already changes temperature by time of day; these are
-- one-off MANUAL overrides, held until the schedule's next profile takes over.
hl.bind(mainMod .. " + F9",         hl.dsp.exec_cmd("systemctl --user is-active --quiet hyprsunset && systemctl --user stop hyprsunset || systemctl --user start hyprsunset")) -- toggle the service
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("hyprctl hyprsunset identity"))         -- filter OFF (natural colors)
hl.bind(mainMod .. " + CTRL + F9",  hl.dsp.exec_cmd("hyprctl hyprsunset temperature 3000")) -- night (warm)
hl.bind(mainMod .. " + ALT + F9",   hl.dsp.exec_cmd("hyprctl hyprsunset temperature 2000")) -- the small hours (very warm)
