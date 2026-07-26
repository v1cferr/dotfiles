-- ── Monitores ──────────────────────────────────────────────────────────────
-- Nomes de conector confirmados via `hyprctl monitors` (Wayland/Arc):
--   DP-2     = LG ULTRAGEAR (1080p 144Hz) → PRINCIPAL, na origem 0x0
--   HDMI-A-3 = TV LG → à esquerda (x negativo), em Full HD (1920x1080@60).
-- Adaptação p/ TV desconectada: com o principal em 0x0, o LG segue sozinho sem
-- offset fantasma; as workspaces 5–8 recaem nele automaticamente.
hl.monitor({ output = "DP-2",     mode = "1920x1080@143.98", position = "0x0",     scale = 1 })
hl.monitor({ output = "HDMI-A-3", mode = "1920x1080@60",     position = "-1920x0", scale = 1 })
hl.monitor({ output = "",         mode = "preferred",        position = "auto",    scale = "auto" })

-- 4 workspaces por monitor: 1–4 no LG (DP-2, principal), 5–8 na TV (HDMI-A-3).
-- default:true = a workspace que abre em cada monitor no boot da sessão.
hl.workspace_rule({ workspace = "1", monitor = "DP-2",     default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2" })
hl.workspace_rule({ workspace = "3", monitor = "DP-2" })
hl.workspace_rule({ workspace = "4", monitor = "DP-2" })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-3", default = true })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-3" })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-3" })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-3" })
