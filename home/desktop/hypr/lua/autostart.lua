-- Autostart. hyprland.start fires ONCE at session boot, not on a reload; hypridle is a
-- systemd --user service instead. What each line does: docs/notes/desktop/hypr.md
hl.on("hyprland.start", function()
  -- Without this the --user services do NOT come up, since LightDM launches a BARE Hyprland.
  hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
  -- LOCKING at boot, through the UNIT and not a loose hyprlock: one owner, and two session-lock
  -- surfaces break the keyboard grab. The machine autologins so Sunshine can come up.
  hl.exec_cmd("systemctl --user start hyprlock.service")
  hl.exec_cmd("qs") -- Quickshell (bar/OSD/media). The QML config is in home/desktop/quickshell/ (hot-reload).
  -- A persistent clipboard: on Wayland the app OWNS the copy, so without this a Flameshot image
  -- dies with flameshot. cliphist's watcher is a declarative service now, not launched here.
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)
