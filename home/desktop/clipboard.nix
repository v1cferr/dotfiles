# Clipboard manager (Wayland) — histórico com PREVIEW de imagem + ícone por TIPO de
# arquivo. cliphist guarda texto/imagem/URI (serviço declarativo); o picker é o rofi
# (-show-icons) com tema Tokyo Night. O bind SUPER+SHIFT+V vive em
# home/desktop/hypr/lua/keybinds.lua. Substitui o antigo picker wofi (só texto).
#
# Migração do meu Arch (cliphist-rofi-img.sh) COM melhorias: além de thumbnail de
# imagem, agora arquivos copiados (URI file://…) ganham ÍCONE do tipo (zip/vídeo/pdf…)
# resolvido pelo tema de ícones (Fluent-dark). Regra 1/3: idiomático e declarativo.
{ pkgs, config, osConfig, ... }:

let
  palette = config.my.theme.palette; # cores do tema ativo (home/desktop/palette.nix)
  # clipboard-menu: monta a lista do cliphist com ícones e mostra no rofi; a escolha
  # volta pro clipboard (cole com Ctrl+V). Uma passada só (lista → rofi → decode → copy).
  #   • imagem (binary png/jpg/…) → decodifica pro cache e usa como THUMBNAIL
  #   • arquivo (URI file://…)     → ícone NOMEADO do tipo (pela extensão)
  #   • texto                      → ícone de texto
  clipboardMenu = pkgs.writeShellApplication {
    name = "clipboard-menu";
    runtimeInputs = with pkgs; [ cliphist wl-clipboard rofi coreutils gnugrep ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"
      mkdir -p "$cache"

      # extensão → nome de ícone freedesktop (resolvido pelo tema Fluent-dark).
      ext_icon() {
        case "$1" in
          zip|tar|gz|xz|bz2|7z|rar|zst)             echo application-x-archive ;;
          mp4|mkv|avi|mov|webm|flv|wmv|m4v)         echo video-x-generic ;;
          mp3|flac|wav|ogg|opus|m4a|aac)            echo audio-x-generic ;;
          png|jpg|jpeg|gif|bmp|webp|svg|tiff|ico)   echo image-x-generic ;;
          pdf)                                      echo application-pdf ;;
          doc|docx|odt|rtf)                         echo x-office-document ;;
          xls|xlsx|ods|csv)                         echo x-office-spreadsheet ;;
          sh|bash|zsh|py|js|ts|lua|nix|c|cpp|rs|go|java|rb) echo text-x-script ;;
          txt|md|log|json|xml|yaml|yml|toml|conf|ini)       echo text-x-generic ;;
          iso|img|bin|exe|appimage)                 echo application-x-executable ;;
          *)                                        echo application-x-generic ;;
        esac
      }

      # monta a entrada do rofi (linha + \0icon\x1f<ícone>) por item e pipa pro rofi.
      choice="$(
        cliphist list | while IFS= read -r line; do
          case "$line" in
            *"binary data"*)
              ext="$(printf '%s' "$line" | grep -oiE '[[:space:]](png|jpe?g|bmp|gif|webp)[[:space:]]' | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | head -1)"
              if [ -n "$ext" ]; then
                [ "$ext" = jpeg ] && ext=jpg
                id="$(printf '%s' "$line" | cut -f1)"
                thumb="$cache/$id.$ext"
                [ -f "$thumb" ] || { printf '%s' "$line" | cliphist decode > "$thumb" 2>/dev/null || true; }
                printf '%s\0icon\x1f%s\n' "$line" "$thumb"
              else
                printf '%s\0icon\x1fapplication-x-generic\n' "$line"
              fi
              ;;
            *file://*)
              e="$(printf '%s' "$line" | grep -oiE '\.[A-Za-z0-9]+' | tail -1 | tr -d '.' | tr '[:upper:]' '[:lower:]')"
              printf '%s\0icon\x1f%s\n' "$line" "$(ext_icon "$e")"
              ;;
            *)
              printf '%s\0icon\x1ftext-x-generic\n' "$line"
              ;;
          esac
        done | rofi -dmenu -i -show-icons -p "󰅇 Clipboard" -theme clipboard
      )"

      [ -n "$choice" ] || exit 0
      printf '%s' "$choice" | cliphist decode | wl-copy
    '';
  };
in
{
  # Serviço declarativo do cliphist (substitui o `wl-paste --watch` do autostart do
  # hypr). allowImages = sobe também o watcher de imagem, além do de texto.
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  home.packages = [
    pkgs.rofi # picker com -show-icons (thumbnail de imagem / ícone por tipo)
    clipboardMenu
  ];

  # Cores do TEMA ATIVO (my.theme) — a paleta do rofi segue a fonte única. icon-theme =
  # Fluent-dark (o mesmo do sistema) resolve os ícones nomeados por tipo de arquivo.
  # `font` explícito: sem ele o rofi cai no default "mono 12". NÃO comentar dentro do
  # .rasi com '#' — ali '#' abre literal de cor e quebra o parse do tema inteiro.
  xdg.configFile."rofi/clipboard.rasi".text = ''
    configuration {
      show-icons:  true;
      icon-theme:  "${config.my.theme.iconTheme}";
      font:        "${osConfig.my.fonts.ui} 12";
    }
    * {
      tn-bg:     #${palette.bg};
      tn-bg-alt: #${palette.surface};
      tn-fg:     #${palette.text};
      tn-muted:  #${palette.dim};
      tn-blue:   #${palette.blue};
      tn-border: #${palette.border};
      background-color: transparent;
      text-color:       @tn-fg;
    }
    window {
      width:            720px;
      background-color: @tn-bg;
      border:           2px;
      border-color:     @tn-blue;
      border-radius:    12px;
      padding:          12px;
    }
    mainbox { spacing: 10px; children: [ inputbar, listview ]; }
    inputbar {
      background-color: @tn-bg-alt;
      border-radius:    8px;
      padding:          8px 12px;
      spacing:          8px;
      children:         [ prompt, entry ];
    }
    prompt { text-color: @tn-blue; }
    entry  { placeholder: "search…"; placeholder-color: @tn-muted; }
    listview { lines: 8; columns: 1; scrollbar: false; spacing: 4px; }
    element {
      padding:       6px 8px;
      spacing:       10px;
      border-radius: 8px;
      children:      [ element-icon, element-text ];
    }
    element normal.normal   { background-color: transparent; text-color: @tn-fg; }
    element selected.normal { background-color: @tn-blue;     text-color: @tn-bg; }
    element-icon { size: 2.2em; vertical-align: 0.5; }
    element-text { vertical-align: 0.5; }
  '';
}
