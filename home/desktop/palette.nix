# PALETA DE CORES = FONTE ÚNICA do tema (SSOT). Trocar de tema = mudar `my.theme.name`
# (1 linha) e dar rebuild. Cada preset traz os hexes OFICIAIS exatos da paleta. Os
# consumidores em Nix (rofi/lockscreen/flameshot) leem `config.my.theme.palette.<cor>`;
# os hot-reload (Quickshell/Hyprland) leem os arquivos de dados gerados abaixo (não dá
# pra o Nix escrever dentro das árvores symlinkadas do quickshell/hypr).
{
  config,
  lib,
  osConfig,
  ...
}:

let
  cfg = config.my.theme;

  # Presets — hexes SEM '#', 6 dígitos (cada consumidor formata como precisa).
  palettes = {
    # Tokyo Night (variante Night) — github.com/folke/tokyonight.nvim
    tokyo-night = {
      bg = "1a1b26"; # fundo base
      surface = "1f2335"; # elevado (cards/popovers)
      track = "292e42"; # trilho/realce sutil
      border = "414868"; # bordas (terminal_black)
      text = "c0caf5"; # texto primário (fg)
      subtext = "a9b1d6"; # texto secundário (fg_dark)
      dim = "565f89"; # texto apagado (comment)
      accent = "7aa2f7"; # cor de acento (= blue)
      blue = "7aa2f7";
      cyan = "7dcfff";
      sky = "89ddff"; # blue5
      teal = "73daca"; # green1
      green = "9ece6a";
      yellow = "e0af68";
      orange = "ff9e64";
      red = "f7768e";
      magenta = "bb9af7";
      purple = "9d7cd8";
      pink = "ff007c"; # magenta2
      shadow = "0f0f0f"; # sombra das janelas
    };
    # Catppuccin Mocha — catppuccin.com/palette (2º preset p/ demonstrar a troca).
    catppuccin-mocha = {
      bg = "1e1e2e"; # base
      surface = "313244"; # surface0
      track = "45475a"; # surface1
      border = "585b70"; # surface2
      text = "cdd6f4";
      subtext = "a6adc8"; # subtext0
      dim = "6c7086"; # overlay0
      accent = "89b4fa"; # blue
      blue = "89b4fa";
      cyan = "74c7ec"; # sapphire
      sky = "89dceb";
      teal = "94e2d5";
      green = "a6e3a1";
      yellow = "f9e2af";
      orange = "fab387"; # peach
      red = "f38ba8";
      magenta = "cba6f7"; # mauve
      purple = "cba6f7"; # mauve (Mocha não separa purple)
      pink = "f5c2e7";
      shadow = "11111b"; # crust
    };
    # Gruvbox Dark — github.com/morhetz/gruvbox (paleta quente; ótimo p/ testar a troca).
    gruvbox-dark = {
      bg = "282828"; # bg0
      surface = "3c3836"; # bg1
      track = "504945"; # bg2
      border = "665c54"; # bg3
      text = "ebdbb2"; # fg1
      subtext = "d5c4a1"; # fg2
      dim = "928374"; # gray
      accent = "fe8019"; # orange (o acento icônico do Gruvbox)
      blue = "83a598";
      cyan = "8ec07c"; # aqua
      sky = "83a598";
      teal = "8ec07c";
      green = "b8bb26";
      yellow = "fabd2f";
      orange = "fe8019";
      red = "fb4934";
      magenta = "d3869b";
      purple = "b16286";
      pink = "d3869b";
      shadow = "1d2021"; # bg0_hard
    };
  };

  p = palettes.${cfg.name};
in
{
  options.my.theme = {
    name = lib.mkOption {
      type = lib.types.enum (lib.attrNames palettes);
      default = "tokyo-night";
      description = "Tema ativo (fonte única de cores). Mudar aqui recolore o desktop inteiro.";
    };
    palette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      description = "Paleta resolvida do tema ativo (hexes sem '#'). Lida pelos módulos.";
    };
    # Tema de ÍCONES: é tema, mas NÃO deriva do preset de cores — o Fluent-dark é o look
    # Windows 11 e vale em qualquer paleta. O PACOTE fica em theme.nix (gtk.iconTheme.package),
    # então trocar = esta linha + o pacote lá.
    iconTheme = lib.mkOption {
      type = lib.types.str;
      default = "Fluent-dark";
      description = "Tema de ícones (SSOT). Lido por theme.nix (dconf/GTK/kdeglobals) e pelos temas do rofi.";
    };
    # Cursor: mesmo raciocínio. O pacote (bibata-cursors) fica em theme.nix.
    cursor = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Bibata-Modern-Ice";
        description = "Tema do cursor (SSOT). Lido por theme.nix (dconf) e pelo Hyprland via hypr-colors.lua.";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "Tamanho do cursor em px (SSOT) — aqui é global, não por contexto.";
      };
    };
  };
  # A FONTE de UI não fica aqui: é `my.fonts.ui`, em system/hardware/fonts.nix, junto
  # do pacote (regra 4) — este módulo cuida do resto do tema. Consumidores leem via osConfig.

  config = {
    my.theme.palette = p;

    # Dados p/ o Quickshell: Theme.qml lê via FileView+JsonAdapter (cores com '#').
    # Vai junto o uiFont — o .qml é symlink hot-reload, o Nix não escreve dentro dele,
    # então este JSON é o único caminho até o Quickshell (nome do arquivo é histórico).
    home.file.".config/theme/quickshell-colors.json".text = builtins.toJSON (
      lib.mapAttrs (_: v: "#${v}") p // { uiFont = osConfig.my.fonts.ui; }
    );

    # Dados p/ o Hyprland: appearance.lua e environment.lua dão dofile e usam a tabela
    # (hexes sem '#'). Vão junto cursor/tamanho — mesmo motivo do JSON acima: o Lua é
    # symlink hot-reload, o Nix não interpola lá dentro (nome do arquivo é histórico).
    home.file.".config/theme/hypr-colors.lua".text =
      "-- Gerado pelo Nix (my.theme). NÃO editar à mão — fonte em home/desktop/palette.nix.\n"
      + "return {\n"
      + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k} = \"${v}\",\n") p)
      + "  cursorTheme = \"${cfg.cursor.name}\",\n"
      + "  cursorSize = \"${toString cfg.cursor.size}\",\n"
      + "}\n";
  };
}
