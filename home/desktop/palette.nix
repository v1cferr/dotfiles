# PALETA DE CORES = FONTE ÚNICA do tema (SSOT). Trocar de tema = mudar `my.theme.name`
# (1 linha) e dar rebuild. Cada preset traz os hexes OFICIAIS exatos da paleta. Os
# consumidores em Nix (rofi/lockscreen/flameshot) leem `config.my.theme.palette.<cor>`;
# os hot-reload (Quickshell/Hyprland) leem os arquivos de dados gerados abaixo (não dá
# pra o Nix escrever dentro das árvores symlinkadas do quickshell/hypr).
{ config, lib, ... }:

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
  };

  config = {
    my.theme.palette = p;

    # Dados p/ o Quickshell: Theme.qml lê via FileView+JsonAdapter (cores com '#').
    home.file.".config/theme/quickshell-colors.json".text = builtins.toJSON (
      lib.mapAttrs (_: v: "#${v}") p
    );

    # Dados p/ o Hyprland: appearance.lua dá dofile e usa a tabela (hexes sem '#').
    home.file.".config/theme/hypr-colors.lua".text =
      "-- Gerado pelo Nix (my.theme). NÃO editar à mão — fonte em home/desktop/palette.nix.\n"
      + "return {\n"
      + lib.concatStrings (lib.mapAttrsToList (k: v: "  ${k} = \"${v}\",\n") p)
      + "}\n";
  };
}
