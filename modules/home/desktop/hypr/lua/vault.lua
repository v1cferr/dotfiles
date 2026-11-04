-- App vault: when the session locks, every sensitive app moves to special:vault, so whoever
-- unlocks the screen still meets a password per app (the Quickshell PAM prompt). Nothing hides
-- while the PC is in use. A speed bump, NOT a security boundary: docs/notes/desktop/vault.md

-- app name -> Lua patterns over the lowercased window class (X11 and Wayland ids differ).
local APPS = {
  discord  = { "^discord$", "^vesktop$" },
  telegram = { "^telegramdesktop$", "^org%.telegram%.desktop$" },
  chatgpt  = { "chatgpt" },
  obsidian = { "obsidian" },
  zen      = { "^zen" },
  librewolf = { "^librewolf$" },
}
local VAULT_WS = "special:vault"

-- Global on purpose: the prompt calls back through `hyprctl eval 'vault.release("discord")'`.
vault = vault or {}
local hidden = {}  -- app -> true while its windows sit in the vault
local busy = false -- our own moves fire window.active too; ignore them

local function app_of(w)
  local class = (w and w.class or ""):lower()
  for app, patterns in pairs(APPS) do
    for _, p in ipairs(patterns) do
      if class:match(p) then return app end
    end
  end
end

local function windows_of(app)
  local list = {}
  for _, w in ipairs(hl.get_windows()) do
    if w.mapped and app_of(w) == app then list[#list + 1] = w end
  end
  return list
end

local function move(w, ws)
  hl.dispatch(hl.dsp.window.move({ workspace = ws, window = "address:" .. w.address, follow = false }))
end

-- Where a window was before the vault, kept as a tag ON the window: it survives `hyprctl reload`
-- (Lua state does not) and dies with the window. Floating, size and fullscreen survive the move.
local FROM = "vault_from_"
local function tag(w, sign, ws)
  hl.dispatch(hl.dsp.window.tag({ tag = sign .. FROM .. ws, window = "address:" .. w.address }))
end
local function origin_of(w)
  local tags = type(w.tags) == "table" and w.tags or { w.tags }
  for _, t in ipairs(tags) do
    if type(t) == "string" and t:sub(1, #FROM) == FROM then return t:sub(#FROM + 1) end
  end
end

-- Focusing a vaulted window OPENS the special on its monitor, and toggle_special only acts on the
-- focused monitor: focus each one showing the vault, then close it.
local function close_view()
  for _, m in ipairs(hl.get_monitors()) do
    local s = hl.get_active_special_workspace(m.name)
    if s and s.name == VAULT_WS then
      hl.dispatch(hl.dsp.focus({ monitor = m.name }))
      hl.dispatch(hl.dsp.workspace.toggle_special("vault"))
    end
  end
end

-- Hides every window of the app; asks for the password only when the user was reaching for it.
local asked_at = {} -- app -> os.time() of the last prompt, so one reach is one prompt
local function hide(app, ask)
  local wins = windows_of(app)
  if #wins == 0 then return end
  busy = true
  for _, w in ipairs(wins) do
    if w.workspace and w.workspace.name ~= VAULT_WS then
      if not origin_of(w) then tag(w, "+", w.workspace.name) end
      move(w, VAULT_WS)
    end
  end
  close_view()
  busy = false
  hidden[app] = true
  if ask and os.time() - (asked_at[app] or 0) > 2 then
    asked_at[app] = os.time()
    hl.exec_cmd("qs ipc call vault ask " .. app)
  end
end

-- Every window goes back to the workspace it left (the active one if it has no tag), and the one
-- used last gets the focus, which takes you to it.
function vault.release(app)
  if not hidden[app] then return end
  local here = hl.get_active_workspace()
  local wins, last = windows_of(app), nil
  busy = true
  for _, w in ipairs(wins) do
    local from = origin_of(w)
    move(w, from or (here and here.name) or "1")
    if from then tag(w, "-", from) end
    if not last or w.focus_history_id < last.focus_history_id then last = w end
  end
  busy = false
  hidden[app] = nil
  if last then hl.dispatch(hl.dsp.focus({ window = "address:" .. last.address })) end
end

-- Session lock (lockscreen.service's ExecStartPre) and SUPER+CTRL+L: every open vault app hides.
function vault.lock_all()
  for app in pairs(APPS) do hide(app, false) end
end

-- SUPER+CTRL+V: the hidden apps, space separated, for the prompt to offer.
function vault.hidden()
  local names = {}
  for app in pairs(hidden) do names[#names + 1] = app end
  table.sort(names)
  return table.concat(names, " ")
end

-- For a person at the terminal: `hyprctl repl 'return vault.status()'`.
function vault.status()
  local rows = {}
  for app in pairs(APPS) do
    if #windows_of(app) > 0 then rows[#rows + 1] = app .. "=" .. (hidden[app] and "hidden" or "open") end
  end
  table.sort(rows)
  return "[" .. table.concat(rows, " ") .. "]"
end

-- Focused from the vault itself (alt-tab, a stray dispatch): back in, and ask.
hl.on("window.active", function(w)
  if busy then return end
  local app = app_of(w)
  if app and hidden[app] then hide(app, true) end
end)

-- A NEW window of a hidden app (a second browser window, a Discord popout) joins the others.
hl.on("window.open", function(w)
  local app = app_of(w)
  if app and hidden[app] then hide(app, true) end
end)

-- After a `hyprctl reload` the table is empty: windows still in the vault stay hidden.
for _, w in ipairs(hl.get_windows()) do
  local app = app_of(w)
  if app and w.workspace and w.workspace.name == VAULT_WS then hidden[app] = true end
end
