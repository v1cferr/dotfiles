# Waybar Configuration

Configuração personalizada do Waybar para Hyprland com estilo baseado em pílulas.

## 📋 Layout

### Canto Esquerdo

- **Workspaces (Hyprland)** - Navegação entre espaços de trabalho
- **Spotify** - Música tocando e controles de reprodução

### Centro

- **Temperatura** - Monitoramento térmico do sistema
- **Relógio** - Data e hora atual

### Canto Direito

- **Áudio/Volume** - Controle de volume do PulseAudio
- **Rede/WiFi** - Status da conexão de rede
- **CPU** - Uso do processador
- **Memória** - Uso da RAM
- **Idioma** - Layout do teclado atual
- **System Tray** - Ícones do sistema

## 🎨 Estilo

A configuração utiliza um design baseado em **pílulas** com:

- **Cores**: Tema Catppuccin Mocha
- **Fonte**: CaskaydiaCove Nerd Font, JetBrainsMono Nerd Font, Fira Code Nerd Font
- **Transparência**: Fundo semi-transparente com efeitos visuais
- **Responsividade**: Adaptação automática para diferentes resoluções

## 📦 Dependências

### Obrigatórias

- `waybar` - Barra de status
- `hyprland` - Compositor Wayland
- `playerctl` - Controle de mídia para Spotify
- `pulseaudio` - Sistema de áudio
- Nerd Fonts (CaskaydiaCove, JetBrainsMono ou Fira Code)

### Opcionais

- `swaync` - Centro de notificações (recomendado)

  ```bash
  # Para instalar o SwayNC
  yay -S swaync
  ```

## 🚀 Instalação

1. **Copie os arquivos de configuração:**

   ```bash
   # Via GNU Stow (recomendado)
   cd ~/dotfiles
   stow waybar
   
   # Ou manualmente
   cp -r waybar/.config/waybar ~/.config/
   cp waybar/scripts/* ~/.local/bin/ # ou outro diretório no PATH
   ```

2. **Torne os scripts executáveis:**

   ```bash
   chmod +x ~/.config/waybar/scripts/spotify.sh
   chmod +x ~/.local/bin/restart-waybar.sh
   ```

3. **Reinicie o Waybar:**

   ```bash
   ~/.local/bin/restart-waybar.sh
   ```

## 🔧 Personalização

### Cores

As cores podem ser ajustadas no arquivo `style.css`. O tema atual usa o Catppuccin Mocha:

```css
/* Principais cores do tema */
--background: rgba(30, 30, 46, 0.9);
--surface: rgba(49, 50, 68, 0.8);
--text: #cdd6f4;
--accent: #89b4fa;
```

### Módulos

Para adicionar/remover módulos, edite o array correspondente em `config.jsonc`:

```jsonc
"modules-left": ["hyprland/workspaces", "custom/spotify"],
"modules-center": ["temperature", "clock"],
"modules-right": ["pulseaudio", "network", "cpu", "memory", "hyprland/language", "tray"]
```

### Fontes

Para usar fontes diferentes, ajuste a propriedade `font-family` no `style.css`:

```css
* {
    font-family: "Sua Fonte", "CaskaydiaCove Nerd Font", monospace;
}
```

## 🎵 Spotify Integration

O módulo de Spotify funciona através do script `spotify.sh` que utiliza `playerctl`.

**Controles disponíveis:**

- **Click esquerdo**: Play/Pause
- **Click direito**: Próxima música
- **Scroll up**: Aumentar volume
- **Scroll down**: Diminuir volume

**Formatos de exibição:**

- 🎵 Tocando: "Artista - Música"
- ⏸️ Pausado: "⏸️ Pausado"
- ⏹️ Parado: "Sem música"

## 📱 Responsividade

A configuração se adapta automaticamente a diferentes resoluções e monitores. Para ajustar para sua configuração específica:

1. **Largura da barra**: Ajustada automaticamente
2. **Altura da barra**: 44px (mínimo requerido pelos módulos)
3. **Margens**: Configurável via `margin` no `config.jsonc`

## 🔍 Troubleshooting

### Waybar não inicia

1. Verifique os logs: `waybar --log-level debug`
2. Valide o JSON: `waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css`

### Spotify não funciona

1. Verifique se o `playerctl` está instalado: `which playerctl`
2. Teste o comando: `playerctl status`
3. Verifique se o Spotify está rodando

### Ícones não aparecem

1. Instale uma Nerd Font: `yay -S ttf-cascadia-code-nerd`
2. Atualize o cache de fontes: `fc-cache -fv`
3. Reinicie o Waybar

### Módulo de temperatura não funciona

1. Verifique se há sensores: `sensors`
2. Instale lm-sensors: `sudo pacman -S lm-sensors`
3. Configure os sensores: `sudo sensors-detect`

## 📄 Arquivos

```bash
waybar/
├── .config/waybar/
│   ├── config.jsonc        # Configuração principal
│   ├── style.css          # Estilização CSS
│   └── scripts/
│       └── spotify.sh     # Script do Spotify
└── scripts/
    └── restart-waybar.sh  # Script para reiniciar
```

## 🎯 Recursos Utilizados

- [Waybar Wiki](https://github.com/Alexays/Waybar/wiki)
- [Hyprland Documentation](https://hyprland.org/Docs/)
- [Catppuccin Theme](https://catppuccin.com/)
- [Nerd Fonts](https://www.nerdfonts.com/)

---

**Criado por:** v1cferr  
**Último update:** 2025-08-31
