-- Hyprland's modular entrypoint (Lua 0.55): it ONLY loads the modules, IN ORDER, and `hl` stays
-- visible inside each one. Hot-reloaded from the repo. The tree: docs/notes/hypr.md
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
