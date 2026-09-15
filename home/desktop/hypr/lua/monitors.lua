-- Monitors. primary = the ASUS at 0x0, secondary = the LG ROTATED on the LEFT; keeping the main
-- one at the origin is what keeps the layout stable. See docs/notes/desktop/hypr.md

-- Nix data with a SELF-CONTAINED FALLBACK: a bare dofile would BLOW UP and abort the config,
-- and "autostart" loads later, so the session would come up with no services at all.
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-1", secondary = "DP-2" } end

hl.monitor({ output = M.primary, mode = "2560x1440@180", position = "0x0", scale = 1 })

-- transform 1 = 90 degrees, so the LG is 1080x1920 LOGICAL: x = -1080 puts it on the left and
-- y = -240 lines its middle up with the shorter primary, which is where the pointer crosses.
hl.monitor({ output = M.secondary, mode = "1920x1080@143.98", position = "-1080x-240", scale = 1, transform = 1 })

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
