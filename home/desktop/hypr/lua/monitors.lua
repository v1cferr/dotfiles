-- ── Monitores ──────────────────────────────────────────────────────────────
-- Nomes de conector confirmados via `hyprctl monitors` (Wayland/Arc):
--   primary   = LG ULTRAGEAR (1080p 144Hz) → PRINCIPAL, na origem 0x0
--   secondary = TV LG → à esquerda (x negativo), em Full HD (1920x1080@60).
-- Adaptação p/ TV desconectada: com o principal em 0x0, o LG segue sozinho sem
-- offset fantasma; as workspaces 5–8 recaem nele automaticamente.
local M = loadThemeData("monitors.lua", { primary = "DP-2", secondary = "HDMI-A-3" })

hl.monitor({ output = M.primary,     mode = "1920x1080@143.98", position = "0x0",     scale = 1 })
hl.monitor({ output = M.secondary, mode = "1920x1080@60",     position = "-1920x0", scale = 1 })
hl.monitor({ output = "",         mode = "preferred",        position = "auto",    scale = "auto" })

-- 4 workspaces por monitor: 1–4 no LG (principal), 5–8 na TV (secundário).
-- Nomes de conector vêm do Nix (my.monitors) — SSOT em home/desktop/monitors.nix.
-- default:true = a workspace que abre em cada monitor no boot da sessão.
hl.workspace_rule({ workspace = "1", monitor = M.primary,     default = true })
hl.workspace_rule({ workspace = "2", monitor = M.primary })
hl.workspace_rule({ workspace = "3", monitor = M.primary })
hl.workspace_rule({ workspace = "4", monitor = M.primary })
hl.workspace_rule({ workspace = "5", monitor = M.secondary, default = true })
hl.workspace_rule({ workspace = "6", monitor = M.secondary })
hl.workspace_rule({ workspace = "7", monitor = M.secondary })
hl.workspace_rule({ workspace = "8", monitor = M.secondary })
