-- ── Ambiente (hl.env) ──────────────────────────────────────────────────────
-- Cursor: Bibata-Modern-Ice (pacote bibata-cursors vem do system/). XCURSOR_*
-- cobre XWayland/apps legados e o fallback do Hyprland; HYPRCURSOR_* é o
-- formato nativo (cai no XCursor se não houver variante hyprcursor do tema).
-- Apps GTK pegam o cursor pelo gsettings (home/theme.nix), não daqui.
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")

-- Tema Qt/KDE (Dolphin): faz o Qt seguir o GTK escuro. O módulo qt
-- (home/theme.nix) já define isso como session var, mas em Wayland a sessão
-- nem sempre carrega — fixar aqui garante o dark nos apps abertos pelo Hyprland.
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")

-- Qt roda nativo em Wayland (fallback xcb): o flameshot precisa disso pra
-- posicionar o overlay/picker certo; xcb cobre qualquer app Qt sem Wayland.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
