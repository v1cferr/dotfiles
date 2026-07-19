# CONFIG do kitty (~/.config/kitty/kitty.conf), declarado. É o terminal default do
# Hyprland (SUPER+Q, keybind em home/hypr.nix). O binário `kitty` vem do system/
# (systemPackages); aqui é só aparência + comportamento. O prompt é o starship
# (home/starship.nix) e o shell é o zsh (home/zsh.nix).
{ ... }:

{
  programs.kitty = {
    enable = true;

    # Mesma fonte do resto do sistema (JetBrains Mono Nerd Font → ícones do starship).
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    # Esquema de cores (arquivo do pacote kitty-themes, sem o sufixo .conf).
    themeFile = "tokyo_night_night";

    # kitty injeta helpers no shell (ex.: pular entre prompts, abrir output no pager).
    shellIntegration.mode = "enabled";

    settings = {
      background_opacity = "0.95"; # leve transparência (compositor do Hyprland)
      scrollback_lines = 10000; # histórico de rolagem generoso
      enable_audio_bell = false; # sem beep — usa flash visual no lugar
      confirm_os_window_close = 0; # fecha a janela sem pedir confirmação
      window_padding_width = 8; # respiro entre o texto e a borda
      cursor_blink_interval = 0; # cursor fixo (não pisca)
      copy_on_select = "clipboard"; # selecionar já copia pro clipboard
    };

    keybindings = {
      "ctrl+shift+enter" = "new_window"; # nova janela (split) do kitty
      "ctrl+shift+t" = "new_tab"; # nova aba
      "ctrl+equal" = "change_font_size all +1.0"; # aumenta a fonte
      "ctrl+minus" = "change_font_size all -1.0"; # diminui a fonte
      "ctrl+0" = "change_font_size all 0"; # reseta o tamanho da fonte
    };
  };
}
