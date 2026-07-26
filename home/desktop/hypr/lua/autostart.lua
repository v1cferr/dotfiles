-- ── Autostart ───────────────────────────────────────────────────────────────
-- hyprland.start dispara UMA vez no boot da sessão (não em reload). O hypridle
-- NÃO entra aqui: sobe como serviço systemd --user (home/lockscreen.nix).
hl.on("hyprland.start", function()
  -- Sessão systemd --user: importa o env do Wayland e inicia o hyprland-session.target
  -- (BindsTo graphical-session.target). Sem isto os serviços --user (hyprsunset/hypridle/
  -- quickshell) NÃO sobem no login — o LightDM lança o Hyprland cru, sem integração systemd.
  -- O target está declarado em systemd.user.targets (home/desktop/hypr.nix).
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
  hl.exec_cmd("qs") -- Quickshell (bar/OSD/mídia). Config QML em home/desktop/quickshell/ (hot-reload).
  -- watcher do clipboard: escuta cada cópia e grava no histórico do cliphist.
  -- Sem isto o cliphist fica vazio (é o daemon que popula o banco).
  hl.exec_cmd("wl-paste --watch cliphist store")
  -- clipboard persistente: mantém a cópia viva após o app de origem fechar. No
  -- Wayland o dono do clipboard é a app; sem isto a imagem do Flameshot some ao
  -- ele sair (Ctrl+V não cola). Casa com o cliphist (histórico) acima.
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)
