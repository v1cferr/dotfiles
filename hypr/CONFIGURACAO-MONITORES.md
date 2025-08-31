# 🖥️ Configuração de Monitores e Workspaces

## 📊 **Setup Atual:**

### **Monitor Principal (DP-1)** - LG ULTRAGEAR 27" 144Hz
- **Posição**: Esquerda (0x0)
- **Workspaces**: 1, 2, 3, 4
- **Padrão**: Workspace 1

### **Monitor Secundário (HDMI-A-1)** - AOC 22B1W
- **Posição**: Direita (1920x0) 
- **Workspaces**: 5, 6, 7, 8
- **Padrão**: Workspace 5

## ⌨️ **Atalhos de Teclado:**

### **Navegação entre Workspaces:**
- `SUPER + 1-4`: Workspaces do monitor principal (DP-1)
- `SUPER + 5-8`: Workspaces do monitor secundário (HDMI-A-1)
- `SUPER + TAB`: Próximo workspace no mesmo monitor
- `SUPER + SHIFT + TAB`: Workspace anterior no mesmo monitor

### **Navegação entre Monitores:**
- `SUPER + F1`: Foca no monitor principal (DP-1)
- `SUPER + F2`: Foca no monitor secundário (HDMI-A-1)

### **Movimentação de Janelas:**
- `SUPER + SHIFT + 1-4`: Move janela para workspaces do monitor principal
- `SUPER + SHIFT + 5-8`: Move janela para workspaces do monitor secundário
- `SUPER + CTRL + ←`: Move janela para monitor principal (DP-1)
- `SUPER + CTRL + →`: Move janela para monitor secundário (HDMI-A-1)

### **Navegação Rápida:**
- `SUPER + ALT + 1`: Primeiro workspace do monitor principal
- `SUPER + ALT + 4`: Último workspace do monitor principal  
- `SUPER + ALT + 5`: Primeiro workspace do monitor secundário
- `SUPER + ALT + 8`: Último workspace do monitor secundário

### **Outros Atalhos Úteis:**
- `SUPER + scroll`: Navega entre workspaces
- `SUPER + mouse`: Move/redimensiona janelas

## 🎯 **Organização Sugerida:**

### **Monitor Principal (DP-1)** - Trabalho/Principal:
1. **Workspace 1**: Terminal/Desenvolvimento
2. **Workspace 2**: Navegador principal
3. **Workspace 3**: Editor de código
4. **Workspace 4**: Comunicação (Discord/Slack)

### **Monitor Secundário (HDMI-A-1)** - Secundário/Mídia:
5. **Workspace 5**: Mídia/YouTube/Spotify
6. **Workspace 6**: Documentação/Referências
7. **Workspace 7**: Ferramentas sistema
8. **Workspace 8**: Monitoramento/Logs

## 🔧 **Scripts Úteis:**

```bash
# Aplicar configuração de monitores
~/dotfiles/hypr/scripts/setup-monitors.sh

# Recarregar Hyprland
hyprctl reload

# Ver status dos monitores
hyprctl monitors
```

## 📱 **Waybar:**
- Mostra workspaces 1-4 no monitor principal
- Mostra workspaces 5-8 no monitor secundário
- Workspaces persistentes configurados por monitor

**✅ Configuração otimizada para produtividade em dual monitor!**
