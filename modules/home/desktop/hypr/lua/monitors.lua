-- Monitors. The primary sits at 0x0, which is what keeps the layout stable; each panel's mode and
-- the secondary's place are the HOST's (my.monitors). See docs/notes/desktop/hypr.md

-- Nix data with a SELF-CONTAINED FALLBACK: a bare dofile would BLOW UP and abort the config,
-- and "autostart" loads later, so the session would come up with no services at all.
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-1", secondary = "DP-2" } end
-- The fallback is the DESK's layout, field by field: a data file from before the modes existed
-- has the names only, and the desk must not lose its rotation between a pull and a rebuild.
M.primary_mode = M.primary_mode or "2560x1440@180"
M.secondary_mode = M.secondary_mode or "1920x1080@143.98"
M.secondary_position = M.secondary_position or "-1080x-240"
M.secondary_transform = M.secondary_transform or 1 -- 0 is truthy in Lua, so a declared 0 survives

hl.monitor({ output = M.primary, mode = M.primary_mode, position = "0x0", scale = 1 })

hl.monitor({
  output = M.secondary,
  mode = M.secondary_mode,
  position = M.secondary_position,
  scale = 1,
  transform = M.secondary_transform,
})

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- 4 workspaces per monitor; default:true = the one that opens there at boot. No per-workspace
-- `layout`, since scrolling is global (appearance.lua); a dwindle one would need the guard back.
hl.workspace_rule({ workspace = "1", monitor = M.primary,     default = true })
hl.workspace_rule({ workspace = "2", monitor = M.primary })
hl.workspace_rule({ workspace = "3", monitor = M.primary })
hl.workspace_rule({ workspace = "4", monitor = M.primary })
hl.workspace_rule({ workspace = "5", monitor = M.secondary, default = true })
hl.workspace_rule({ workspace = "6", monitor = M.secondary })
hl.workspace_rule({ workspace = "7", monitor = M.secondary })
hl.workspace_rule({ workspace = "8", monitor = M.secondary })
