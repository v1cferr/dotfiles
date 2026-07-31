-- ── Keybinds (paridade com o Arch/Kingston) ─────────────────────────────────
-- Dado gerado pelo Nix, com FALLBACK autocontido: se o arquivo faltar (1º boot antes
-- do rebuild, ou dado novo ainda não gerado), o dofile ESTOURA e aborta a config —
-- e como "autostart" vem depois na ordem de carga, a sessão sobe sem serviços.
-- NÃO usar helper global: o Hyprland não compartilha globais entre os dofile.
local ok_M, M = pcall(dofile, os.getenv("HOME") .. "/.config/theme/monitors.lua")
if not ok_M or type(M) ~= "table" then M = { primary = "DP-2", secondary = "HDMI-A-3" } end

local mainMod = "SUPER"

-- Programas que os binds abaixo chamam (ferramentas adaptadas ao NixOS).
local terminal       = "kitty"            -- SUPER+RETURN
local terminalWithAi = "kitty claude"     -- SUPER+BACKSPACE (Claude Code no terminal)
local launcherApps   = "rofi -show drun -theme launcher" -- SUPER+Q (apps .desktop; ícones+recência)
local launcherRun    = "rofi -show run -theme launcher"  -- SUPER+R (binários no PATH)
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

-- Barra "/" no acesso remoto: o Moonlight NÃO envia a tecla "/ ?" do ABNT2 (bug #1789,
-- tecla internacional). Remapeia SCROLL LOCK (tecla ociosa; este TKL não tem Menu) →
-- "/" e Shift+ScrollLock → "?", via send_shortcut (dispatcher NATIVO do Hyprland, envia
-- o keysym direto pra janela ativa — independe do layout e não depende de exec externo,
-- diferente do wtype que não injetava pelo bind). Mantém o ABNT2; vale local também.
hl.bind("Scroll_Lock",         hl.dsp.send_shortcut({ mods = 0,       key = "slash", window = "activewindow" }))  -- "/"
hl.bind("SHIFT + Scroll_Lock", hl.dsp.send_shortcut({ mods = "SHIFT", key = "slash", window = "activewindow" }))  -- "?" (Shift+/)

-- clipboard: histórico do cliphist no rofi com PREVIEW (thumbnail de imagem + ícone
-- por tipo de arquivo); a escolha volta pro clipboard (cole com Ctrl+V). Script e tema
-- Tokyo Night em home/desktop/clipboard.nix.
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("clipboard-menu"))

-- VPN (paridade Arch): SUPER+N = UFSCar (GlobalProtect), SHIFT+N = FAI (SonicWall/nxBender),
-- CTRL+N = desconecta tudo. Serviços systemd sob demanda (system/net/vpn.nix); o CLI `vpn`
-- liga sem senha via regra polkit.
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("vpn connect ufscar"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("vpn connect fai"))
hl.bind(mainMod .. " + CTRL + N",  hl.dsp.exec_cmd("vpn disconnect all"))

-- reiniciar o Quickshell (raramente necessário — ele faz hot-reload do QML ao
-- salvar; útil só quando o processo trava). `qs kill` para a instância, `qs` sobe.
hl.bind(mainMod .. " + ESCAPE",    hl.dsp.exec_cmd("qs-restart")) -- reinicia o Quickshell (delegate de Repeater não pega no hot-reload)

-- Minimizar: manda as OUTRAS janelas da workspace pra special:minimized (toggle).
hl.bind(mainMod .. " + M",         hl.dsp.exec_cmd("minimize-others"))
hl.bind(mainMod .. " + CTRL + M",  hl.dsp.workspace.toggle_special("minimized"))  -- abrir/fechar a special

-- Foco entre janelas (setas)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- ── Fita do scrolling layout (ws 2 e 6; ver monitors.lua) ───────────────────
-- `move` rola a VISTA sem mexer no foco; com follow_mouse=1 (input.lua) basta passar o
-- mouse sobre a coluna que entrou pra ela receber o teclado. As setas acima continuam
-- valendo: follow_focus (default) já traz a coluna focada pra vista.
hl.bind(mainMod .. " + comma",          hl.dsp.layout("move -col"))       -- fita ← 1 coluna
hl.bind(mainMod .. " + period",         hl.dsp.layout("move +col"))       -- fita → 1 coluna
-- Thumbwheel do MX Master, que o logiops sintetiza como SUPER+CTRL+,/. (mouse.nix).
-- Combo de 3 teclas e NÃO F13/F14 por keycode: `code:191` registra com keycode=0 no
-- `hyprctl binds` (não deu pra provar que dispara), enquanto comma/period registram
-- certo — e sintetizar combo já é padrão provado aqui (o botão de gestos faz isso).
-- Passo pequeno de propósito: o logiops dispara em rajada (issue #310 do PixlOne/logiops),
-- então rajada de 80px vira rolagem suave. Calibrar a velocidade AQUI, não no `interval`.
hl.bind(mainMod .. " + CTRL + comma",   hl.dsp.layout("move -80"))        -- thumbwheel ←
hl.bind(mainMod .. " + CTRL + period",  hl.dsp.layout("move +80"))        -- thumbwheel →
-- Reordenar e redimensionar colunas
hl.bind(mainMod .. " + SHIFT + comma",  hl.dsp.layout("swapcol l"))       -- troca c/ a coluna à esquerda
hl.bind(mainMod .. " + SHIFT + period", hl.dsp.layout("swapcol r"))       -- troca c/ a coluna à direita
hl.bind(mainMod .. " + ALT + comma",    hl.dsp.layout("colresize -conf")) -- cicla largura ↓ (0.333/0.5/0.667/1.0)
hl.bind(mainMod .. " + ALT + period",   hl.dsp.layout("colresize +conf")) -- cicla largura ↑
-- Empilhar/desempilhar janelas dentro da coluna
hl.bind(mainMod .. " + I",              hl.dsp.layout("consume"))         -- puxa a janela pra coluna anterior
hl.bind(mainMod .. " + O",              hl.dsp.layout("expel"))           -- expulsa a janela pra coluna própria
-- `fit active` e NÃO `fit_into_view`: o wiki documenta o segundo, mas o 0.55.4 responde
-- "no such layoutmsg for scrolling". Todas as mensagens de layout exigem janela FOCADA
-- (sem foco elas devolvem "no focused window" e não fazem nada).
hl.bind(mainMod .. " + G",              hl.dsp.layout("fit active"))      -- recentra a coluna ativa
hl.bind(mainMod .. " + SHIFT + G",      hl.dsp.layout("fit expand"))      -- expande a janela pro espaço livre

-- Foco por monitor: F1 = LG (principal) · F2 = TV (secundário). Nomes: my.monitors.
hl.bind(mainMod .. " + F1", hl.dsp.focus({ monitor = M.primary }))
hl.bind(mainMod .. " + F2", hl.dsp.focus({ monitor = M.secondary }))

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
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.move({ monitor = M.secondary }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ monitor = M.primary }))

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
-- SHIFT+VolUp = +claro · SHIFT+VolDown = +escuro · SUPER+SHIFT+B = reset (100%).
-- Reset saiu do SHIFT+code:19 (tecla 0 física): bindar aquilo CONSUMIA o keystroke
-- e, no ABNT2, ")" é Shift+0 → não dava pra fechar parêntese. SUPER+SHIFT+B não
-- rouba tecla de digitação nenhuma.
hl.bind("SHIFT + XF86AudioRaiseVolume", hl.dsp.exec_cmd("brightness-osd up"),    { locked = true, repeating = true })
hl.bind("SHIFT + XF86AudioLowerVolume", hl.dsp.exec_cmd("brightness-osd down"),  { locked = true, repeating = true })
hl.bind(mainMod .. " + SHIFT + B",      hl.dsp.exec_cmd("brightness-osd reset"), { locked = true })

-- Screenshot (Flameshot v14). Print = fluxo nativo (picker + clique de mouse).
-- SUPER+SHIFT+S = fluxo por TECLADO (paridade Arch): abre o picker e entra no submap
-- "screenshot" → 1 = TV (secundário), 2 = principal, Esc cancela. O v14
-- SEMPRE mostra o picker no multi-monitor; os scripts (home/apps/flameshot.nix)
-- sintetizam o clique no preview e resetam o submap sozinhos. Salva em ~/Pictures/Screenshots.
hl.bind("Print",                   hl.dsp.exec_cmd("flameshot gui"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("flameshot-screenshot"))

hl.define_submap("screenshot", function()
  -- posicional: 1 = tela da ESQUERDA (TV), 2 = tela da DIREITA (LG principal).
  hl.bind("1",      hl.dsp.exec_cmd("flameshot-pick " .. M.secondary)) -- secundário (TV, à esquerda)
  hl.bind("2",      hl.dsp.exec_cmd("flameshot-pick " .. M.primary))     -- principal (LG, à direita)
  hl.bind("escape", hl.dsp.exec_cmd("flameshot-cancel"))        -- cancela + sai do submap
end)

-- ── Filtro de luz azul (hyprsunset) ─────────────────────────────────────────
-- O serviço (home/hyprsunset.nix) já troca a temperatura por horário sozinho;
-- estes binds são override MANUAL pontual via IPC (`hyprctl hyprsunset`) — valem
-- até o próximo perfil do schedule assumir. F9 liga/desliga o serviço inteiro.
hl.bind(mainMod .. " + F9",         hl.dsp.exec_cmd("systemctl --user is-active --quiet hyprsunset && systemctl --user stop hyprsunset || systemctl --user start hyprsunset")) -- toggle serviço
hl.bind(mainMod .. " + SHIFT + F9", hl.dsp.exec_cmd("hyprctl hyprsunset identity"))         -- filtro OFF (cores naturais)
hl.bind(mainMod .. " + CTRL + F9",  hl.dsp.exec_cmd("hyprctl hyprsunset temperature 3000")) -- noite (quente)
hl.bind(mainMod .. " + ALT + F9",   hl.dsp.exec_cmd("hyprctl hyprsunset temperature 2000")) -- madrugada (muito quente)
