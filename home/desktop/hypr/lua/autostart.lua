-- ── Autostart ───────────────────────────────────────────────────────────────
-- hyprland.start dispara UMA vez no boot da sessão (não em reload). O hypridle
-- NÃO entra aqui: sobe como serviço systemd --user (home/lockscreen.nix).
hl.on("hyprland.start", function()
  -- Sessão systemd --user: importa o env do Wayland e inicia o hyprland-session.target
  -- (BindsTo graphical-session.target). Sem isto os serviços --user (hyprsunset/hypridle/
  -- quickshell) NÃO sobem no login — o LightDM lança o Hyprland cru, sem integração systemd.
  -- O target está declarado em systemd.user.targets (home/desktop/hypr.nix).
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
  -- TRANCA no boot: a máquina loga sozinha (autologin, system/desktop/desktop.nix) p/ o
  -- Sunshine subir, mas a sessão nasce TRANCADA — o Moonlight cai direto no hyprlock e só
  -- entra com senha. Só no boot da sessão (hyprland.start não dispara em reload).
  -- PAM em desktop.nix.
  -- Pela UNIT, não `hyprlock` solto: o hyprlock tem UM dono (hyprlock.service, em
  -- home/desktop/lockscreen.nix) e é por ele que passam boot, idle e o botão da barra.
  -- Processo solto aqui furaria a idempotência do systemd — o lock do idle subiria uma
  -- 2ª superfície de session-lock por cima desta, e duas quebram o grab do teclado
  -- (o campo de senha para de digitar). O `pidof ||` que morava aqui virou ExecCondition.
  hl.exec_cmd("systemctl --user start hyprlock.service")
  hl.exec_cmd("qs") -- Quickshell (bar/OSD/mídia). Config QML em home/desktop/quickshell/ (hot-reload).
  -- O watcher do cliphist (histórico) agora é serviço declarativo (services.cliphist,
  -- home/desktop/clipboard.nix) — não é mais lançado aqui.
  -- clipboard persistente: mantém a cópia viva após o app de origem fechar. No
  -- Wayland o dono do clipboard é a app; sem isto a imagem do Flameshot some ao
  -- ele sair (Ctrl+V não cola). Casa com o cliphist (histórico) do clipboard.nix.
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)
