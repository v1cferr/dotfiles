# Configuração Harmoniosa: Waybar + Hyprland Tokyo Night 🎨

## ✨ Mudanças Implementadas

### 📱 **Waybar - Bordas Arredondadas**

- **Borda principal**: `border-radius: 10px` com sombra sutil
- **Margens ajustadas**: `margin: 4px 8px 0 8px`
- **Módulos arredondados**: `border-radius: 6px` (normal) → `8px` (hover)
- **Transições suaves**: `transition: all 0.2s/0.3s ease-in-out`

### 🎨 **Cores Tokyo Night Harmoniosas**

- **Background**: `#1e1e2e` (tom escuro suave)
- **Texto**: `#c0caf5` (azul-branco suave)
- **Hover**: `rgba(65, 72, 104, 0.4)` (azul translúcido)
- **Bordas**: `#313244` com sombra `rgba(0, 0, 0, 0.3)`

### 🖼️ **Hyprland - Bordas Sutis**

- **Borda padrão**: `2px` (aumentou de 1px para melhor definição)
- **Cores Tokyo Night**:
  - **Ativa**: `rgba(7aa2f766) rgba(bb9af755)` (azul/roxo suave)
  - **Inativa**: `rgba(41444655)` (cinza muito sutil)

### 🎯 **Bordas Reduzidas para Aplicações Produtivas**

Aplicações que recebem bordas de `1px` para menos distração:

- **Editores**: VS Code, Codium
- **Navegadores**: Firefox, Chrome, Chromium  
- **Terminais**: Kitty, Alacritty, Wezterm, Foot
- **Produtividade**: Obsidian, Notion
- **Comunicação**: Discord, Slack

### 📊 **Workspaces Melhorados**

- **Botões maiores**: `padding: 3px 8px` | `min-width: 20px`
- **Bordas arredondadas**: `6px` → `8px` (hover/ativo)
- **Cores Tokyo Night**:
  - **Inativo**: `#565f89` (cinza-azul sutil)
  - **Hover**: `#7aa2f7` com fundo translúcido
  - **Ativo**: `#7aa2f7` sobre `#1a1b26`
  - **Urgente**: `#f7768e` (vermelho-rosa Tokyo Night)

## 🎯 **Resultado Final**

### ✅ **Simetria Alcançada**

- Waybar com `border-radius: 10px`
- Janelas Hyprland com `rounding = 10px`
- Ambos usando o mesmo raio de curvatura

### ✅ **Menos Distração**

- Bordas sutis com cores Tokyo Night de baixo contraste
- Aplicações focadas com bordas de apenas `1px`
- Transparência sutil mantém hierarquia visual

### ✅ **Harmonia Visual**

- Paleta de cores consistente (Tokyo Night)
- Transições suaves em todos os elementos
- Sombras sutis que não distraem

## 🛠️ **Scripts de Atualização**

### Recarregar Waybar

```bash
./waybar/scripts/update-waybar.sh
```

### Recarregar Hyprland  

```bash
hyprctl reload
```

---

*Configuração implementada em: 02/09/2025*  
*Tema: Tokyo Night harmonioso e não-disruptivo* 🌙✨
