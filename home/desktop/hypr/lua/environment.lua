-- The environment (hl.env). The cursor comes from Nix, and the Qt vars are pinned here because
-- Wayland does not always load the session vars: docs/notes/hypr.md

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

-- The Qt/KDE theme, pinned so apps opened BY Hyprland get the dark look.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")

-- Qt native on Wayland with an xcb fallback: flameshot needs it to place the overlay.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
