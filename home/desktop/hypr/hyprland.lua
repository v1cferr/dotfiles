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
-- Carrega uma tabela de dados GERADA pelo Nix (~/.config/theme/*.lua) com FALLBACK.
-- Por que pcall e não dofile direto: se o arquivo não existir — 1º boot antes do
-- primeiro rebuild, ou dado novo já referenciado no repo mas ainda não gerado — o
-- dofile ESTOURA e aborta o resto da config. Como "autostart" vem depois de
-- "monitors" na lista abaixo, isso derruba o hyprland-session.target e a máquina sobe
-- SEM quickshell/sunshine/hyprpaper: sessão remota inacessível. Aconteceu em 29/07.
function loadThemeData(file, fallback)
  local ok, t = pcall(dofile, os.getenv("HOME") .. "/.config/theme/" .. file)
  if ok and type(t) == "table" then
    return t
  end
  return fallback
end

local dir = os.getenv("HOME") .. "/.config/hypr/lua/"
for _, mod in ipairs({
  "environment", -- hl.env: cursor, tema Qt, plataforma Wayland
  "monitors",    -- hl.monitor + hl.workspace_rule (conectores do my.monitors, ws 1–8)
  "appearance",  -- general/decoration/animations: bordas, blur, shadow, curvas
  "input",       -- teclado ABNT2 + mouse (accel flat, numlock)
  "autostart",   -- hl.on("hyprland.start"): systemd, quickshell, clipboard
  "rules",       -- hl.window_rule: opacity, PiP, Ascension, Flameshot
  "keybinds",    -- todos os hl.bind
}) do
  dofile(dir .. mod .. ".lua")
end
