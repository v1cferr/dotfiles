-- The tape's auto-fill: up to MAX_SHARED columns split the screen evenly (2 = halves, 3 = thirds),
-- so a workspace never shows wallpaper beside its windows; past that it scrolls at half width.
-- keybinds.lua dofiles this ONCE (it is not in hyprland.lua's list) and reuses `fit_soon`.
local MAX_SHARED = 3
local fitAll = hl.dsp.layout("fit all")

local function at_x(w)
  local a = type(w.at) == "table" and w.at or {}
  return a.x or a[1] or 0
end

-- Columns of a workspace = the distinct x of its tiled windows (the Lua API has no column ids).
local function column_count(ws_id)
  local seen, n = {}, 0
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and not w.hidden and not w.floating and w.workspace and w.workspace.id == ws_id then
      local x = at_x(w)
      if not seen[x] then seen[x] = true; n = n + 1 end
    end
  end
  return n
end

-- Layout messages act on the FOCUSED window's workspace, so only that one is refit.
local function fit_now()
  local ws, active = hl.get_active_workspace(), hl.get_active_window()
  if not (ws and active and active.workspace and active.workspace.id == ws.id) or active.floating then return end
  local n = column_count(ws.id)
  if n < 2 then return end -- a lone column is fullscreen_on_one_column's job
  local width = n <= MAX_SHARED and 1 / n or 0.5
  hl.dispatch(hl.dsp.layout(string.format("colresize all %.3f", width)))
  hl.dispatch(fitAll)
end

-- Deferred: the events fire before the layout has placed (or dropped) the window.
local function fit_soon()
  hl.timer(fit_now, { timeout = 60, type = "oneshot" })
end

for _, event in ipairs({ "window.open", "window.destroy", "window.move_to_workspace" }) do
  hl.on(event, fit_soon)
end

return { fit_soon = fit_soon }
