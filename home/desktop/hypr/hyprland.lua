-- ── Entrypoint modular do Hyprland (Lua 0.55) ───────────────────────────────
-- A config foi quebrada por categoria em ~/.config/hypr/lua/*.lua (espelha o
-- layout modular do setup Arch e a regra 5 do projeto: 1 assunto por arquivo).
-- Este arquivo SÓ carrega os módulos, na ordem. `hl` é global e fica visível
-- dentro de cada módulo carregado por dofile.
--
-- HOT-RELOAD: nem este arquivo nem os módulos ficam na store — vêm por
-- mkOutOfStoreSymlink (home/desktop/hypr.nix) dos arquivos reais no repo. Edita
-- qualquer .lua + `hyprctl reload` → aplica na hora, sem rebuild. Os scripts que
-- os binds chamam (minimize-others, brightness-osd, monitor-toggle) entram no
-- PATH via home.packages, então os módulos os invocam por nome.
local dir = os.getenv("HOME") .. "/.config/hypr/lua/"
for _, mod in ipairs({
  "environment", -- hl.env: cursor, tema Qt, plataforma Wayland
  "monitors",    -- hl.monitor + hl.workspace_rule (DP-2/HDMI-A-3, ws 1–8)
  "appearance",  -- general/decoration/animations: bordas, blur, shadow, curvas
  "input",       -- teclado ABNT2 + mouse (accel flat, numlock)
  "autostart",   -- hl.on("hyprland.start"): systemd, quickshell, clipboard
  "rules",       -- hl.window_rule: opacity, PiP, Ascension, Flameshot
  "keybinds",    -- todos os hl.bind
}) do
  dofile(dir .. mod .. ".lua")
end
