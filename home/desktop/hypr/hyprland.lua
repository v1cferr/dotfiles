-- ── Hyprland's modular entrypoint (Lua 0.55) ────────────────────────────────
-- The config was broken up by category into ~/.config/hypr/lua/*.lua (it mirrors the Arch
-- setup's modular layout and the project's rule 5: 1 subject per file).
-- This file ONLY loads the modules, in order. `hl` is global and stays visible inside every
-- module loaded through dofile.
--
-- HOT-RELOAD: neither this file nor the modules live in the store, they come through
-- mkOutOfStoreSymlink (home/desktop/hypr.nix) from the real files in the repo. Edit any .lua plus
-- `hyprctl reload` and it applies right away, with no rebuild. The scripts the binds call
-- (minimize-others, brightness-osd, monitor-toggle) enter the PATH through home.packages, so the
-- modules invoke them by name.
local dir = os.getenv("HOME") .. "/.config/hypr/lua/"
for _, mod in ipairs({
  "environment", -- hl.env: the cursor, the Qt theme, the Wayland platform
  "monitors",    -- hl.monitor plus hl.workspace_rule (my.monitors' connectors, ws 1 to 8)
  "appearance",  -- general/decoration/animations: borders, blur, shadow, curves
  "input",       -- the ABNT2 keyboard plus the mouse (flat accel, numlock)
  "autostart",   -- hl.on("hyprland.start"): systemd, quickshell, clipboard
  "rules",       -- hl.window_rule: opacity, PiP, Ascension, Flameshot
  "keybinds",    -- every hl.bind
}) do
  dofile(dir .. mod .. ".lua")
end
