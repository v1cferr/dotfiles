-- ── Keybinds (paridade com o Arch/Kingston) ─────────────────────────────────
local mainMod = "SUPER"

-- Programas que os binds abaixo chamam (ferramentas adaptadas ao NixOS).
local terminal       = "kitty"            -- SUPER+RETURN
local terminalWithAi = "kitty claude"     -- SUPER+BACKSPACE (Claude Code no terminal)
local launcherApps   = "wofi --show drun" -- SUPER+Q (apps .desktop) [era rofi drun]
local launcherRun    = "wofi --show run"  -- SUPER+R (binários no PATH) [era rofi run]
local fileManager    = "dolphin"          -- SUPER+E [era thunar]
local sound          = "pavucontrol"      -- SUPER+S (mixer de áudio)
local bluetooth      = "blueman-manager"  -- SUPER+B

-- Apps e ações principais
hl.bind(mainMod .. " + Q",         hl.dsp.exec_cmd(launcherApps))                 -- launcher (apps)
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(launcherRun))                  -- launcher (run)
hl.bind(mainMod .. " + RETURN",    hl.dsp.exec_cmd(terminal))                     -- terminal
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(terminalWithAi))               -- terminal c/ IA (Claude Code)
hl.bind(mainMod .. " + E",         hl.dsp.exec_cmd(fileManager))                  -- arquivos (Dolphin)
hl.bind(mainMod .. " + S",         hl.dsp.exec_cmd(sound))                        -- mixer de áudio
hl.bind(mainMod .. " + B",         hl.dsp.exec_cmd(bluetooth))                    -- bluetooth
hl.bind(mainMod .. " + C",         hl.dsp.window.close())                         -- fechar janela
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))    -- flutuar
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))  -- fullscreen
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo())                        -- pseudo (dwindle)
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprctl reload"))             -- recarregar config
-- lock: loginctl → logind → lock_cmd do hypridle (home/lockscreen.nix); nunca duplica o hyprlock.
hl.bind(mainMod .. " + L",         hl.dsp.exec_cmd("loginctl lock-session"))      -- travar tela

-- clipboard: histórico do cliphist no wofi; a escolha volta pro clipboard (cole com Ctrl+V).
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- reiniciar o Quickshell (raramente necessário — ele faz hot-reload do QML ao
-- salvar; útil só quando o processo trava). `qs kill` para a instância, `qs` sobe.
hl.bind(mainMod .. " + ESCAPE",    hl.dsp.exec_cmd("bash -lc 'qs kill; sleep 0.3; qs &'"))

-- Minimizar: manda as OUTRAS janelas da workspace pra special:minimized (toggle).
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("minimize-others"))
hl.bind(mainMod .. " + CTRL + M",  hl.dsp.workspace.toggle_special("minimized"))  -- abrir/fechar a special

-- Foco entre janelas (setas)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Foco por monitor: F1 = LG (DP-2, principal) · F2 = TV (HDMI-A-3)
hl.bind(mainMod .. " + F1", hl.dsp.focus({ monitor = "DP-2" }))
hl.bind(mainMod .. " + F2", hl.dsp.focus({ monitor = "HDMI-A-3" }))

-- Liga/desliga a TV (HDMI-A-3) no Hyprland, à mão. A TV mantém o link HDMI vivo
-- desligada → o DRM segue "connected", o monitor-watch não recebe evento e sobra
-- o "monitor fantasma". Desligar recolhe os workspaces 5–8 pro LG; ligar restaura.
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("monitor-toggle"))

-- Workspaces 1–8 (SUPER troca; SUPER+SHIFT move a janela). 1–4 no LG, 5–8 na TV.
for i = 1, 8 do
  hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- Navegação relativa (workspace anterior/próxima) por TAB e por scroll do mouse.
hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse_down",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",    hl.dsp.focus({ workspace = "e-1" }))

-- Mover a janela ativa entre monitores: CTRL+← p/ TV (esquerda), CTRL+→ p/ LG (direita).
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ monitor = "HDMI-A-3" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ monitor = "DP-2" }))

-- Mouse: mover / redimensionar janela
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Teclas de mídia / volume / brilho ───────────────────────────────────────
-- locked = funciona com a tela travada; repeating = repete enquanto segura.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })  -- +vol (teto 100%)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })  -- -vol
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })  -- mudo saída
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })  -- mudo microfone
-- play/pause/next/prev via playerctl (só locked; não faz sentido repetir).
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
-- brilho = gamma do hyprsunset (desktop sem backlight); OSD nativo do Quickshell.
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightness-osd up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightness-osd down"), { locked = true, repeating = true })
-- Brilho (gamma), já que o teclado não tem teclas de brilho:
-- SHIFT+VolUp = +claro · SHIFT+VolDown = +escuro · SHIFT+0 = reset (100%).
-- Reset por code:19 (tecla 0 física): no ABNT2 Shift+0 vira ")" (o keysym muda
-- com shift), então bindar "SHIFT + 0" não pegaria — o keycode ignora isso.
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("brightness-osd up"),    { locked = true, repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("brightness-osd down"),  { locked = true, repeating = true })
hl.bind("SHIFT + code:19",              hl.dsp.exec_cmd("brightness-osd reset"), { locked = true })

-- Screenshot: Print ou SUPER+SHIFT+S (estilo Windows) → editor do flameshot
-- cobrindo as duas telas (a window_rule está em rules.lua). Salva em ~/Pictures/Screenshots.
hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"))

-- ── Filtro de luz azul (hyprsunset) ─────────────────────────────────────────
-- O serviço (home/hyprsunset.nix) já troca a temperatura por horário sozinho;
-- estes binds são override MANUAL pontual via IPC (`hyprctl hyprsunset`) — valem
-- até o próximo perfil do schedule assumir. F9 liga/desliga o serviço inteiro.
hl.bind(mainMod .. " + F9",         hl.dsp.exec_cmd("systemctl --user is-active --quiet hyprsunset && systemctl --user stop hyprsunset || systemctl --user start hyprsunset")) -- toggle serviço
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("hyprctl hyprsunset identity"))         -- filtro OFF (cores naturais)
hl.bind(mainMod .. " + CTRL + F9",  hl.dsp.exec_cmd("hyprctl hyprsunset temperature 3000")) -- noite (quente)
hl.bind(mainMod .. " + ALT + F9",   hl.dsp.exec_cmd("hyprctl hyprsunset temperature 2000")) -- madrugada (muito quente)
