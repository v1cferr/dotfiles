-- App vault: a sensitive app left unfocused for `grace` seconds (or any of them once the session
-- locks) moves to special:vault and only comes back through the Quickshell PAM prompt. A speed
-- bump against a curious passer-by, NOT a security boundary: docs/notes/desktop/vault.md

-- app name -> Lua patterns over the lowercased window class (X11 and Wayland ids differ).
local APPS = {
  discord  = { "^discord$", "^vesktop$" },
  zapfast  = { "^zapfast$" },
  telegram = { "^telegramdesktop$", "^org%.telegram%.desktop$" },
  chatgpt  = { "chatgpt" },
  obsidian = { "obsidian" },
  zen      = { "^zen" },
  librewolf = { "^librewolf$" },
}
local GRACE = 300 -- seconds unfocused before an app hides (my.vault.grace in spirit; edit here)
local VAULT_WS = "special:vault"

-- Global on purpose: the prompt calls back through `hyprctl eval 'vault.release("discord")'`.
vault = vault or {}
local last_seen = {} -- app -> os.time() it last lost focus (or was released)
local hidden = {}    -- app -> true while its windows sit in the vault
local current = nil  -- the app that holds focus now, if any
local playing = {}   -- app -> true while one of its MPRIS players plays (Vault.qml pushes it)
local busy = false   -- our own moves fire window.active too; ignore them

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
    if not (w.workspace and w.workspace.name == VAULT_WS) then move(w, VAULT_WS) end
  end
  close_view()
  busy = false
  hidden[app] = true
  if current == app then current = nil end
  if ask and os.time() - (asked_at[app] or 0) > 2 then
    asked_at[app] = os.time()
    hl.exec_cmd("qs ipc call vault ask " .. app)
  end
end

function vault.release(app)
  local ws = hl.get_active_workspace()
  if not (hidden[app] and ws) then return end
  local wins = windows_of(app)
  busy = true
  for _, w in ipairs(wins) do move(w, tostring(ws.id)) end
  busy = false
  hidden[app], last_seen[app] = nil, os.time()
  if wins[1] then hl.dispatch(hl.dsp.focus({ window = "address:" .. wins[1].address })) end
end

-- Session lock (lockscreen.service) and SUPER+SHIFT+L: every open vault app hides at once.
function vault.lock_all()
  for app in pairs(APPS) do hide(app, false) end
end

-- Vault.qml calls this whenever MPRIS playback changes, with the players' desktop entries ("zen").
-- A playing app is being watched, not abandoned: the grace skips it, and its clock starts over when
-- it stops, so a paused stream gets the full 5 minutes.
function vault.set_playing(entries)
  local now_playing = {}
  for _, e in ipairs(entries) do
    local app = app_of({ class = e })
    if app then now_playing[app] = true end
  end
  for app in pairs(playing) do
    if not now_playing[app] and last_seen[app] then last_seen[app] = os.time() end
  end
  playing = now_playing
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
  local now, rows = os.time(), {}
  for app in pairs(APPS) do
    local state = hidden[app] and "hidden" or playing[app] and "playing"
      or app == current and "focused" or last_seen[app] and ("idle " .. (now - last_seen[app]) .. "s")
    if state then rows[#rows + 1] = app .. "=" .. state end
  end
  table.sort(rows)
  return "[" .. table.concat(rows, " ") .. "]"
end

hl.on("window.active", function(w)
  if busy then return end
  local now, app = os.time(), app_of(w)
  if current and current ~= app then last_seen[current] = now end
  if app and hidden[app] then
    hide(app, true) -- focused from the vault itself (alt-tab, a stray dispatch): back in, and ask
  else
    current = app
  end
end)

-- A NEW window of a hidden app (a second browser window, a Discord popout) joins the others; a
-- fresh app born in the background starts its clock now.
hl.on("window.open", function(w)
  local app = app_of(w)
  if not app then return end
  if hidden[app] then
    hide(app, true)
  elseif app ~= current then
    last_seen[app] = last_seen[app] or os.time()
  end
end)

-- The grace clock: an unfocused app past GRACE hides, even when visible on the other monitor.
hl.timer(function()
  local now = os.time()
  for app in pairs(APPS) do
    if app ~= current and not hidden[app] and not playing[app] and last_seen[app] and now - last_seen[app] > GRACE then
      hide(app, false)
    end
  end
end, { timeout = 30000, type = "repeat" })

-- After a `hyprctl reload` the tables are empty: windows still in the vault stay hidden, the
-- focused app stays current and every other open one restarts its clock.
current = app_of(hl.get_active_window())
for _, w in ipairs(hl.get_windows()) do
  local app = app_of(w)
  if app and w.workspace and w.workspace.name == VAULT_WS then
    hidden[app] = true
  elseif app and app ~= current then
    last_seen[app] = os.time()
  end
end
-- And who is playing, which the reload forgot: Vault.qml pushes it again.
hl.exec_cmd("qs ipc call vault sync")
