-- ── Autostart ───────────────────────────────────────────────────────────────
-- hyprland.start fires ONCE when the session boots (not on a reload). hypridle does NOT go here:
-- it comes up as a systemd --user service (home/lockscreen.nix).
hl.on("hyprland.start", function()
  -- The systemd --user session: it imports the Wayland env and starts hyprland-session.target
  -- (BindsTo graphical-session.target). Without this the --user services (hyprsunset/hypridle/
  -- quickshell) do NOT come up at login, since LightDM launches a bare Hyprland with no systemd
  -- integration. The target is declared in systemd.user.targets (home/desktop/hypr.nix).
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
  -- LOCKING at boot: the machine logs itself in (autologin, system/desktop/desktop.nix) so
  -- Sunshine can come up, but the session is born LOCKED, so Moonlight lands straight on hyprlock
  -- and only gets in with the password. Only at session boot (hyprland.start does not fire on a
  -- reload). PAM is in desktop.nix.
  -- Through the UNIT, not a loose `hyprlock`: hyprlock has ONE owner (hyprlock.service, in
  -- home/desktop/lockscreen.nix) and boot, idle and the bar's button all go through it. A loose
  -- process here would break systemd's idempotence: the idle lock would raise a 2nd session-lock
  -- surface on top of this one, and two of them break the keyboard grab (the password field stops
  -- typing). The `pidof ||` that used to live here became an ExecCondition.
  hl.exec_cmd("systemctl --user start hyprlock.service")
  hl.exec_cmd("qs") -- Quickshell (bar/OSD/media). The QML config is in home/desktop/quickshell/ (hot-reload).
  -- cliphist's watcher (the history) is now a declarative service (services.cliphist,
  -- home/desktop/clipboard.nix), so it is not launched here anymore.
  -- A persistent clipboard: it keeps the copy alive after the source app closes. On Wayland the
  -- clipboard's owner is the app, so without this the Flameshot image disappears when it exits
  -- (Ctrl+V pastes nothing). It pairs with cliphist (the history) from clipboard.nix.
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)
