# Waybar Tokyo Night Theme - São Carlos Edition

## 🎨 Personalização Completa

Esta configuração personalizada do Waybar inclui:

### 🌃 Tema Tokyo Night
- **Cores autênticas** do Tokyo Night Storm
- **Gradientes dinâmicos** nos elementos ativos
- **Efeitos hover** com cores temáticas
- **Transparências** e sombras modernas

### 🌤️ Clima de São Carlos/SP
- **Temperatura atual** de São Carlos, São Paulo
- **Condições climáticas** em português
- **Atualização automática** a cada 10 minutos
- **Click para abrir** previsão completa

### 📊 Módulos Incluídos
1. **Workspaces** - Ícones personalizados com numeração
2. **Window** - Título da janela ativa com ícones
3. **Clock** - Relógio com ícones baseados na hora do dia
4. **Weather** - Clima de São Carlos/SP
5. **System Stats** - CPU e RAM com ícones dinâmicos
6. **Network Rate** - Velocidade de download/upload
7. **Volume** - Volume com ícones baseados no nível
8. **Player** - Controle de mídia (Spotify, etc.)
9. **Bluetooth** - Status e dispositivos conectados
10. **Temperature** - Temperatura da CPU e GPU

### 🔧 Scripts Personalizados
Todos os scripts estão em `~/.config/waybar/scripts/`:

- `weather.sh` - Clima usando wttr.in
- `system_stats.sh` - CPU e RAM com ícones dinâmicos
- `cpu_gpu_temp.sh` - Temperaturas com alertas visuais
- `volume.sh` - Volume com ícones baseados no nível
- `net_rate.sh` - Taxa de rede com formatação legível
- `bluetooth_status.sh` - Status Bluetooth com dispositivos
- `playerctl.sh` - Controle de mídia melhorado
- `clock_center.sh` - Relógio com ícones de hora

### 🎯 Características Especiais

#### Ícones Dinâmicos
- **Temperatura**: ❄️ (frio) → 🌡️ (normal) → 🔥 (quente) → 🚨 (crítico)
- **Volume**: 🔇 (mudo) → 🔈 (baixo) → 🔊 (médio) → 📢 (alto)
- **Hora**: 🌅 (manhã) → ☀️ (tarde) → 🌆 (fim de tarde) → 🌙 (noite)
- **CPU/RAM**: 💤 (baixo) → ⚡ (médio) → 🔥 (alto) → 🚨 (crítico)

#### Interatividade
- **Click no clima**: Abre previsão do tempo
- **Scroll nos workspaces**: Navega entre workspaces
- **Scroll no volume**: Controla volume
- **Click no player**: Play/pause
- **Click no Bluetooth**: Abre gerenciador

### 🛠️ Utilização

#### Reiniciar Waybar
```bash
~/.config/waybar/restart_waybar.sh
```

#### Testar scripts individuais
```bash
cd ~/.config/waybar/scripts
./weather.sh      # Testar clima
./system_stats.sh # Testar CPU/RAM
./volume.sh       # Testar volume
```

### 🎨 Personalização Adicional

#### Alterar cores
Edite `~/.config/waybar/style.css` e ajuste as cores:
- `#7aa2f7` - Azul principal (Tokyo Night)
- `#bb9af7` - Roxo (acentos)
- `#2ac3de` - Ciano (weather)
- `#9ece6a` - Verde (network)
- `#ff9e64` - Laranja (volume)
- `#f7768e` - Vermelho (temperatura)

#### Adicionar mais workspaces
Edite a seção `persistent-workspaces` em `config.jsonc`:
```json
"persistent-workspaces": {
  "*": 10  // Para 10 workspaces
}
```

### 📦 Dependências
- `waybar` - Status bar
- `playerctl` - Controle de mídia
- `pactl` - Controle de áudio (PulseAudio)
- `bluetoothctl` - Controle do Bluetooth
- `sensors` - Temperatura do hardware
- `nvidia-smi` - Temperatura da GPU NVIDIA (opcional)
- `curl` - Para dados do clima

### 🌟 Recursos Avançados
- **Auto-reload**: Use `./restart_waybar.sh` para aplicar mudanças
- **Multi-monitor**: Suporte automático para múltiplos monitores
- **Responsive**: Adapta-se automaticamente ao tamanho da tela
- **Performance**: Scripts otimizados para baixo uso de CPU

---

**Criado com ❤️ para São Carlos/SP**
*Theme baseado no Tokyo Night por Enkia*
