-- Monitors. primary = the LG at 0x0, secondary = the TV on the LEFT; keeping the main one at
-- the origin is what makes a disconnected TV clean. See docs/notes/desktop/hypr.md

-- Nix data with a SELF-CONTAINED FALLBACK: a bare dofile would BLOW UP and abort the config,
-- and "autostart" loads later, so the session would come up with no services at all.
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-2", secondary = "HDMI-A-3" } end

hl.monitor({ output = M.primary,     mode = "1920x1080@143.98", position = "0x0",     scale = 1 })
hl.monitor({ output = M.secondary, mode = "1920x1080@60",     position = "-1920x0", scale = 1 })
hl.monitor({ output = "",         mode = "preferred",        position = "auto",    scale = "auto" })

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
