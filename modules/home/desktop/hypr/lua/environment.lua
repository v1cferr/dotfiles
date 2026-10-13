-- The environment (hl.env). The cursor and the Qt vars come from Nix, and are set here because
-- Wayland does not always load the session vars: docs/notes/desktop/hypr.md

-- Nix data with a SELF-CONTAINED FALLBACK: a bare dofile would BLOW UP and abort the config,
-- and "autostart" loads later, so the session would come up with no services at all.
local ok_T, T = pcall(dofile, os.getenv("HOME") .. "/.config/theme/hypr-colors.lua")
if not ok_T or type(T) ~= "table" then T = { cursorTheme = "Bibata-Modern-Ice", cursorSize = "24" } end

-- XCURSOR_* covers XWayland/legacy plus Hyprland's fallback; HYPRCURSOR_* is the native format.
-- GTK apps take the cursor from gsettings, not from here.
hl.env("XCURSOR_THEME", T.cursorTheme)
hl.env("XCURSOR_SIZE", T.cursorSize)
hl.env("HYPRCURSOR_THEME", T.cursorTheme)
hl.env("HYPRCURSOR_SIZE", T.cursorSize)

-- The Qt theme, from Nix (qt.* in theme.nix): apps opened BY Hyprland get the same pair.
if T.qtPlatformTheme then hl.env("QT_QPA_PLATFORMTHEME", T.qtPlatformTheme) end
if T.qtStyle then hl.env("QT_STYLE_OVERRIDE", T.qtStyle) end

-- Qt native on Wayland with an xcb fallback: flameshot needs it to place the overlay.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
