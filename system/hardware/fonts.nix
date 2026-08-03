# ═══════════════════════════════════════════════════════════════════════════
# FONTES E TIPOGRAFIA — FONTE ÚNICA (SSOT) da família de UI: `my.fonts.ui`.
#
# Mora aqui, e não no my.theme (home/desktop/palette.nix, que cuida das CORES),
# por dois motivos: o PACOTE da fonte é nível-sistema (regra 4) → nome e pacote
# ficam juntos; e o fontconfig abaixo também precisa do nome, e módulo de sistema
# não lê opção do home-manager. Os consumidores de USUÁRIO leem via `osConfig`
# (mesmo padrão do my.services em system/services/toggles.nix): GTK+Qt
# (home/desktop/theme.nix), kitty, hyprlock, rofi e o JSON do Quickshell.
#
# Trocar de fonte = 1 linha (`my.fonts.ui`) + o pacote correspondente na lista.
# O TAMANHO fica em cada consumidor: 11pt no GTK, 12pt no kitty/rofi, e o lockscreen
# varia por widget — é contexto, não tema.
# ═══════════════════════════════════════════════════════════════════════════
{
  pkgs,
  lib,
  config,
  ...
}:

{
  options.my.fonts.ui = lib.mkOption {
    type = lib.types.str;
    default = "JetBrainsMono Nerd Font";
    description = "Família da fonte de UI (SSOT). Lida pelo fontconfig e, via osConfig, pelos módulos do home/.";
  };

  config.fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      # ── COBERTURA (o resto do Unicode que a Nerd Font não tem) ──────────────
      # A JetBrainsMono NF cobre Latin/Grego/Cirílico + os símbolos patcheados, e
      # SÓ. Emoji, CJK, matemática, setas e dingbats saem por FALLBACK — e sem
      # ninguém declarado o fontconfig resolve por ordem própria, terminando no
      # `unifont` (bitmap 16px que vem do enableDefaultPackages e é o único a
      # cobrir faixas como U+0870/U+2FFC): é ele o quadradinho pixelado que
      # aparecia em título de stream e planilha. Estes três entram pra que o
      # fallback seja ESCOLHA e não acidente — e ficam DECLARADOS mesmo os que já
      # vinham de graça pelo enableDefaultPackages, senão a renderização depende
      # de um default do NixOS que ninguém aqui pediu.
      noto-fonts # Sans/Serif proporcionais + Symbols/Symbols2: a maior cobertura geral
      noto-fonts-color-emoji # emoji COLORIDO (CBDT); o monochrome-emoji é o oposto do que se quer
      noto-fonts-cjk-sans # japonês/chinês/coreano (nome de stream, chat da Twitch)
      # Métricas da Microsoft p/ o OnlyOffice (home/apps/office.nix) abrir .docx/.xlsx
      # com o layout certo — sem elas o fontconfig substitui e a paginação anda.
      corefonts # Arial, Times New Roman, Courier New, Verdana… (Office ≤2003)
      vista-fonts # Calibri, Cambria, Consolas… (o .docx moderno usa Calibri por padrão)
    ];
    fontconfig = {
      enable = true;
      # Estética "laboratório": a fonte de UI também em menus/navegador. É o que
      # responde quando um documento pede fonte que não está instalada (ver acima).
      # A SSOT segue PRIMEIRA em toda lista — o que vem depois só é consultado pro
      # glifo que ela não tem, então a aparência não muda, só para de faltar coisa.
      # O emoji vai no FIM de cada genérica de propósito: no fim ele nunca ganha de
      # uma fonte de texto, mas é alcançado direto em vez de por sorte na fila.
      defaultFonts = {
        monospace = [
          config.my.fonts.ui
          "Noto Sans Mono"
          "Noto Color Emoji"
        ];
        sansSerif = [
          config.my.fonts.ui
          "Noto Sans"
          "Noto Color Emoji"
        ];
        serif = [
          config.my.fonts.ui
          "Noto Serif"
          "Noto Color Emoji"
        ];
        emoji = [ "Noto Color Emoji" ]; # explícito: é o default do NixOS, mas não se herda default silencioso
      };
    };
  };
}
