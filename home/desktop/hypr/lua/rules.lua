-- ── Window rules ────────────────────────────────────────────────────────────
-- Portado do window-rules.conf do Arch, adaptado à API Lua 0.55.

-- Transparência sutil em tudo: ativa 0.98 / inativa 0.96 (contraste + wallpaper).
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
  monitor = "DP-2",
  size = "1920 1080",
  center = true,
  fullscreen = true,
  opacity = "1.0 override 1.0 override",
  idle_inhibit = "focus",
})

-- ── Screenshot (Flameshot v13 + grim) ───────────────────────────────────────
-- Config em home/apps/flameshot.nix. PROBLEMA multi-monitor: o grim captura os
-- dois monitores (3840x1080), mas o overlay do editor nasce SÓ no monitor da
-- origem → não cobre o desktop inteiro se o move/size não baterem com o bounding
-- box. FIX (o clássico pré-v14): esticar a janela do overlay pelos DOIS monitores
-- — float + move = canto do bounding box + size = soma das telas (3840x1080). Aí
-- o overlay cobre tudo e a seleção funciona em qualquer tela. opacity/no_blur/
-- no_shadow: o overlay é um frame congelado, não herda transparência/blur globais.
-- Arranjo atual: HDMI-A-3 (TV) @ -1920x0 · DP-2 (principal) @ 0x0 → o canto
-- superior-esquerdo do desktop é (-1920, 0), por isso o move é "-1920 0".
--
-- match por TÍTULO (não class): no v13/Wayland a janela do overlay tem class
-- VAZIA e title exatamente "flameshot" (^...$ pra não casar o VS Code editando
-- este arquivo). suppress_event=fullscreen: o overlay nasce fullscreen (cobre 1
-- só monitor) — suprimir isso deixa o float+move+size assumirem.
hl.window_rule({
  name = "flameshot-overlay",
  match = { title = "^flameshot$" },

  no_anim = true,
  float = true,
  move = "-1920 0",
  size = "3840 1080",
  opacity = "1.0 override 1.0 override",
  no_blur = true,
  no_shadow = true,
  rounding = 0,
  suppress_event = "fullscreen",
})
