-- ── Ambiente (hl.env) ──────────────────────────────────────────────────────
-- Cursor vindo do Nix (my.theme.cursor): mesma tabela gerada por palette.nix que a
-- aparência usa — este .lua é symlink hot-reload, o Nix não interpola aqui dentro.
-- Dado gerado pelo Nix, com FALLBACK autocontido: se o arquivo faltar (1º boot antes
-- do rebuild, ou dado novo ainda não gerado), o dofile ESTOURA e aborta a config —
-- e como "autostart" vem depois na ordem de carga, a sessão sobe sem serviços.
-- NÃO usar helper global: o Hyprland não compartilha globais entre os dofile.
local ok_T, T = pcall(dofile, os.getenv("HOME") .. "/.config/theme/hypr-colors.lua")
if not ok_T or type(T) ~= "table" then T = { cursorTheme = "Bibata-Modern-Ice", cursorSize = "24" } end

-- XCURSOR_* cobre XWayland/apps legados e o fallback do Hyprland; HYPRCURSOR_* é o
-- formato nativo (cai no XCursor se não houver variante hyprcursor do tema).
-- Apps GTK pegam o cursor pelo gsettings (home/theme.nix), não daqui.
hl.env("XCURSOR_THEME", T.cursorTheme)
hl.env("XCURSOR_SIZE", T.cursorSize)
hl.env("HYPRCURSOR_THEME", T.cursorTheme)
hl.env("HYPRCURSOR_SIZE", T.cursorSize)

-- Tema Qt/KDE (Dolphin): faz o Qt seguir o GTK escuro. O módulo qt
-- (home/theme.nix) já define isso como session var, mas em Wayland a sessão
-- nem sempre carrega — fixar aqui garante o dark nos apps abertos pelo Hyprland.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")

-- Qt roda nativo em Wayland (fallback xcb): o flameshot precisa disso pra
-- posicionar o overlay/picker certo; xcb cobre qualquer app Qt sem Wayland.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
