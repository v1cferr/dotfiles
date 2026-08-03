# Cheatsheet de keybinds no rofi (SUPER+H) — lista TODOS os binds do Hyprland.
#
# GERADO do keybinds.lua em RUNTIME, nunca escrito à mão: uma lista duplicada viraria
# mentira no primeiro bind novo. O arquivo lido é ~/.config/hypr/lua/keybinds.lua, que é
# mkOutOfStoreSymlink pro repo (home/desktop/hypr.nix) — então o cheatsheet acompanha até
# edição com hot-reload, sem rebuild.
#
# Por que SUPER+H e não SUPER+/: o Moonlight NÃO envia a tecla "/ ?" do ABNT2 (bug #1789,
# a mesma razão do remap do ScrollLock em keybinds.lua), então SUPER+/ morreria no acesso
# remoto. H é livre e passa em qualquer caminho.
#
# O pacote rofi vem de clipboard.nix (não redeclara — mesmo tool p/ launcher/clipboard/aqui).
{
  pkgs,
  config,
  osConfig,
  ...
}:

let
  palette = config.my.theme.palette; # cores do tema ativo (home/desktop/palette.nix)

  # Parser em awk. Regras que ele segue, todas ditadas pelo formato real do keybinds.lua:
  #   • grupo      = 1ª linha do bloco de comentário logo ACIMA do bind;
  #   • descrição  = comentário no FIM da linha do bind; sem ele, cai pro texto do grupo;
  #   • submap     = binds dentro de hl.define_submap ganham prefixo, senão "1"/"2"/"Esc"
  #                  apareceriam soltos e sem sentido na lista.
  # Dois detalhes que quebraram versões anteriores e por isso estão explícitos:
  #   • o comentário é achado pela ÚLTIMA " -- " da linha, não por regex de "sem hífen":
  #     descrições legítimas contêm hífen ("no-op", "qs-restart") e sumiam;
  #   • as teclas são traduzidas TOKEN A TOKEN (comma → ","), não com gsub cego, senão
  #     "left" dentro de "mouse_left" também seria substituído.
  parser = pkgs.writeText "keybinds-cheatsheet.awk" ''
    function clean(c) { sub(/^-- ?/, "", c); gsub(/─/, "", c); sub(/^ +| +$/, "", c); return c }
    function short(t) {
      # corta só na 1ª ". " (fim de frase). NÃO cortar em ": " — grupos como
      # "Mouse: mover / redimensionar janela" virariam o inútil "Mouse".
      if (match(t, /\. /)) t = substr(t, 1, RSTART - 1)
      sub(/[.:]$/, "", t)
      if (length(t) > 66) t = substr(t, 1, 63) "…"
      return t
    }
    function tailcomment(l,   p, best) {
      best = 0; p = index(l, " -- ")
      while (p > 0) { best = p; p = index(substr(l, best + 4), " -- "); if (p > 0) p += best + 3 }
      return best ? substr(l, best + 4) : ""
    }
    function pretty(k,   n, a, i, o, t) {
      n = split(k, a, / *\+ */); o = ""
      for (i = 1; i <= n; i++) {
        t = a[i]
        if      (t == "comma")       t = ","
        else if (t == "period")      t = "."
        else if (t == "mouse_left")  t = "roda ←"
        else if (t == "mouse_right") t = "roda →"
        else if (t == "mouse_up")    t = "roda ↑"
        else if (t == "mouse_down")  t = "roda ↓"
        else if (t == "mouse:272")   t = "clique esq"
        else if (t == "mouse:273")   t = "clique dir"
        else if (t == "mouse:274")   t = "clique meio"
        else if (t == "left")  t = "←"; else if (t == "right") t = "→"
        else if (t == "up")    t = "↑"; else if (t == "down")  t = "↓"
        else if (t == "RETURN") t = "Enter"; else if (t == "ESCAPE" || t == "escape") t = "Esc"
        else if (t == "BACKSPACE") t = "Backspace"
        o = (o == "" ? t : o " + " t)
      }
      return o
    }
    /^[[:space:]]*$/ { inblk = 0; next }
    /hl\.define_submap\(/ { if (match($0, /"[^"]+"/)) submap = substr($0, RSTART + 1, RLENGTH - 2); next }
    /^end\)/ { submap = ""; next }
    /^--/ { if (!inblk) { blk = clean($0); inblk = 1 } next }
    /^[[:space:]]*hl\.bind\(/ {
      inblk = 0
      if (blk != "") { group = blk; blk = "" }
      line = $0
      desc = tailcomment(line); sub(/ +$/, "", desc)
      k = line; sub(/^[^(]*\(/, "", k); sub(/,.*$/, "", k)
      gsub(/mainMod/, "\"SUPER\"", k); gsub(/ *\.\. */, "", k); gsub(/"/, "", k)
      if (k ~ /i$/) sub(/i$/, "1…8", k)
      gsub(/  +/, " ", k); sub(/^ +| +$/, "", k)
      if (desc == "") desc = short(group)
      if (submap != "") desc = "[submap " submap "] " desc
      printf "%-26s  %s\n", pretty(k), desc
    }
  '';

  cheatsheet = pkgs.writeShellApplication {
    name = "keybinds-cheatsheet";
    runtimeInputs = with pkgs; [
      gawk
      rofi
    ];
    text = ''
      src="$HOME/.config/hypr/lua/keybinds.lua"
      # Falha ALTO se o symlink sumir: um cheatsheet vazio mentiria dizendo "não há binds".
      if [ ! -r "$src" ]; then
        rofi -e "keybinds-cheatsheet: não consegui ler $src" -theme cheatsheet
        exit 1
      fi
      # Só exibe: a escolha é descartada (é referência, não um executor de ações).
      awk -f ${parser} "$src" | rofi -dmenu -i -p "󰌌 Keybinds" -theme cheatsheet > /dev/null
    '';
  };
in
{
  home.packages = [ cheatsheet ];

  # `font` explícito: sem ele o rofi cai no default "mono 12". A my.fonts.ui também é a
  # monospace do sistema (system/hardware/fonts.nix), então as colunas alinham.
  # NÃO comentar dentro do .rasi com '#': ali '#' abre literal de cor e quebra o parse.
  xdg.configFile."rofi/cheatsheet.rasi".text = ''
    configuration {
      show-icons: false;
      matching:   "fuzzy";
      font:       "${osConfig.my.fonts.ui} 11";
    }
    * {
      tn-bg:     #${palette.bg};
      tn-bg-alt: #${palette.surface};
      tn-fg:     #${palette.text};
      tn-muted:  #${palette.dim};
      tn-blue:   #${palette.blue};
      background-color: transparent;
      text-color:       @tn-fg;
    }
    window {
      width:            900px;
      background-color: @tn-bg;
      border:           2px;
      border-color:     @tn-blue;
      border-radius:    12px;
      padding:          14px;
    }
    mainbox { spacing: 12px; children: [ inputbar, listview ]; }
    inputbar {
      background-color: @tn-bg-alt;
      border-radius:    8px;
      padding:          10px 14px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }
    prompt { text-color: @tn-blue; }
    entry  { placeholder: "Filtrar por tecla ou ação…"; placeholder-color: @tn-muted; }
    listview { lines: 20; columns: 1; scrollbar: true; spacing: 2px; }
    scrollbar { handle-color: @tn-blue; handle-width: 4px; }
    element { padding: 4px 10px; border-radius: 6px; }
    element normal.normal   { background-color: transparent; text-color: @tn-fg; }
    element selected.normal { background-color: @tn-blue;     text-color: @tn-bg; }
  '';
}
