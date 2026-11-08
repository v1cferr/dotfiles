-- Autostart. hyprland.start fires ONCE at session boot, not on a reload; hypridle is a
-- systemd --user service instead. What each line does: docs/notes/desktop/hypr.md
hl.on("hyprland.start", function()
  -- Without this the --user services do NOT come up, since LightDM launches a BARE Hyprland.
  -- DISPLAY too: X11-only tray clients (Dropbox) register no icon without Xwayland's display.
  hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP && systemctl --user start hyprland-session.target")
  -- LOCKING at boot, through the UNIT and not a loose hyprlock: one owner, and two session-lock
  -- surfaces break the keyboard grab. The machine autologins so Sunshine can come up.
  hl.exec_cmd("systemctl --user start lockscreen.service")
  hl.exec_cmd("qs") -- Quickshell (bar/OSD/media). The QML config is in modules/home/desktop/quickshell/ (hot-reload).
  -- A persistent clipboard: on Wayland the app OWNS the copy, so without this a Flameshot image
  -- dies with flameshot. The HISTORY is Vicinae's (a --user service), not launched here.
  hl.exec_cmd("wl-clip-persist --clipboard regular")
end)

-- The autostart panel's `hide = true` apps (no tray-only flag) leave a marker named after their PID:
-- that PID's first window goes to special:minimized, unfocused. SUPER+CTRL+M shows it.
local HIDE_DIR = (os.getenv("XDG_RUNTIME_DIR") or "") .. "/autostart-hide/"
hl.on("window.open", function(w)
  if w.pid and os.remove(HIDE_DIR .. tostring(w.pid)) then
    hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:" .. w.address, follow = false }))
  end
end)
