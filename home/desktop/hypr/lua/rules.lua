-- ── Window rules ────────────────────────────────────────────────────────────
-- Portado do window-rules.conf do Arch, adaptado à API Lua 0.55.

-- Transparência sutil em tudo: ativa 0.98 / inativa 0.96 (contraste + wallpaper).
local M = dofile(os.getenv("HOME") .. "/.config/theme/monitors.lua")  -- SSOT dos conectores

hl.window_rule({ match = { class = ".*" }, opacity = "0.98 0.96" })
-- Ignora pedidos de "maximizar" dos apps (comporta melhor no tiling).
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
-- Fix de drag do XWayland: janelas sem class/title, flutuantes, que roubam foco.
hl.window_rule({
  match = { class = "^$", title = "^$", xwayland = 1, float = 1, fullscreen = 0 },
  suppress_event = "activate activatefocus",
})
-- Picture-in-Picture (vídeo destacado) sempre 100% opaco.
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, opacity = "1.0" })
-- Ascension (WoW privado via Wine): flutuante centralizado no LG, opaco, sem idle-lock.
hl.window_rule({
  match = { class = "^(ascension\\.exe)$" },
  float = true,
  monitor = M.primary,
  size = "1920 1080",
  center = true,
  fullscreen = true,
  opacity = "1.0 override 1.0 override",
  idle_inhibit = "focus",
})

-- ── Screenshot (Flameshot v14 via portal) ───────────────────────────────────
-- Config em home/apps/flameshot.nix; captura via xdg-desktop-portal (-wlr).
-- Regra portada do meu Arch (v14): o esticão -1920/3840 do fluxo ANTIGO (v13/grim)
-- QUEBRA o v14 — o v14 abre um PICKER de monitor (janela normal) e depois um overlay
-- fullscreen no monitor escolhido. Forçar move/size gigante bagunça o picker. Aqui só
-- deixamos flutuante + centralizado, sem animação; suppress_event=fullscreen mantém o
-- overlay como janela flutuante (não entra no fullscreen do Hyprland → sem o flash do
-- wallpaper ao fechar). opacity/no_blur/no_shadow: o overlay é frame congelado, não
-- herda transparência/blur globais. match por TÍTULO: neste box a janela do flameshot
-- (tanto o picker de monitor quanto o overlay) tem class VAZIA e title "flameshot".
-- Sem float, ela cai no tiling do dwindle (nasce espremida em meia tela) — daí o "bug".
hl.window_rule({
  name = "flameshot-v14-overlay",
  match = { title = "^flameshot$" },

  no_anim = true,
  float = true,
  center = true,
  pin = false,
  opacity = "1.0 override 1.0 override",
  no_blur = true,
  no_shadow = true,
  rounding = 0,
  suppress_event = "fullscreen",
})
