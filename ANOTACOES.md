# Anotações

## Ideias

- [ ] Colocar algum tipo de notificações ou lembretes que sincronizem com a minha agenda do Google ou algo semelhante (via API do Google?)
  - Todo dia a partir das 21h (com horário no máximo de 23h59) preciso fazer o Duolingo sem falta
- [ ] (add info dps)

## Links

- Repositório dos meus próprios dotfiles: <https://github.com/v1cferr/dotfiles> (esse aqui mesmo)
- <https://wiki.hypr.land/Useful-Utilities/>
  - <https://wiki.hypr.land/Useful-Utilities/Must-have/>

## Para fazer

- [ ] Verificar pq na hora de tirar screenshot a waybar não respeita a área do print (**flameshot**)
  - Issue para consultar: <https://github.com/flameshot-org/flameshot/issues/2978#issuecomment-3205971576>
- [ ] Adicionar as configurações do VSCode (dotfiles) nesse repositório <https://github.com/v1cferr/dotfiles> (meu perfil é bem especifico)
- [ ] Adicionar algum Clipboard Manager <https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/>
- [ ] Verificar pq o cursor tá bugando na hora que o **Hyprsunset** ativa (fica com uma coloração mais destacada que o resto da tela)
- [ ] Adicionar uma verificação e sumir o `hyprland/window` quando não tiver nenhuma aplicação rodando em algum workspace (para não poluir a Waybar)
- [ ] Adicionar o dia da semana (*e.g.: Seg 03/09/2025*) na topbar central
- [ ] Verificar meus [MCPs](./vscode/.config/Code/User/mcp.json) essenciais no VSCode <https://code.visualstudio.com/mcp>
- [ ] Verificar se dá para rodar os jogos que quero no [Hydra Launcher](https://aur.archlinux.org/packages/hydra-launcher-bin)
- [ ] Configurar meu [hyprlock](https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/) (tela de bloqueio) e tempo de idle/suspensão do PC

### Bugs

- [ ] Verificar pq não está colando ao selecionar o dado no clipboard history
- [ ] Verificar pq caracteres asiáticos (Chinês principalmente) não estão renderizando corretamente
  - [[4K 60fps] 黃霄雲 Huang Xiaoyun - 生生世世愛 [Official Music Video] 官方完整版MV](https://youtu.be/5xijWQF8uIA)

### Performance

- [ ] Verificar se compensa habilitar **zram**
  - <https://wiki.archlinux.org/title/Zram>
  - <https://www.reddit.com/r/linux/comments/11dkhz7/zswap_vs_zram_in_2023_whats_the_actual_practical/>
  - <https://github.com/hakavlad/nohang>

### Stylish

- [ ] Personalizar o CSS do meu Zen Browser para ter o tema TokyoNight e diminuir o tamanho das fonts (+diminuir o zoom)
- [ ] Adicionar a customização do "MacOS" para todas as janelas
  - <https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme>
  - <https://www.gnome-look.org/p/1681315>
  - Configs: Night, borderless, macos buttons
- [ ] Customizar meu Hyprlock (screenlock) com widgets e no segundo monitor não deixar input para senha

### Menos importantes

## Concluidos

- [x] Verificar pq o cursor está bugado graficamente (fica cinza escuro sem textura) ao rodar o Hearthstone pelo `bottles-cli run -b "Battle.net" -p "Battle.net"`
  - Adicionado `xwayland { force_zero_scaling = true }` no hyprland.conf
- [x] Aumentar a duração das notificações (10 segundos para dar tempo de ler)
- [x] Configurar e documentar o [Hyprsunset](./hypr/.config/hypr/hyprsunset.conf)
- [x] Aumentar levemente o gap entre as janelas quando estão uma ao lado da outra
  - {deaef8161b723c0b4bc5b314331a17bd8ea3b75c}
- [x] Melhorar essa [Waybar](./waybar/) e deixar do jeito que eu quero
  - [x] Deixar o bg transparent (da propria waybar)
  - [x] Sistema de pílulas com ícones do mechabar
  - Inspirações:
    - <https://github.com/sejjy/mechabar>
- [x] Personalizar meu **fastfetch** e colocar o simbolo da Alliance (WoW) invés da logo do Arch
- [x] Trocar <https://wttr.in/S%C3%A3o+Carlos> pela WeatherAPI.com <https://www.weatherapi.com/>
- [x] Adicionar a fonte da JetBrains com icones hehe no terminal do VSCode e geral
- [x] Atualizar meu cursor e selecionar um legal <https://wiki.hypr.land/Hypr-Ecosystem/hyprcursor/>
- [x] Adicionar e configurar meu [swaync](./swaync/) novamente
- [x] Reduzir apenas um pouco a opacidade e blur das mini-pilulas na **Waybar** para ter simetria com o style das próprias janelas no **Hypr**
- [x] Programar o próximo **snapshot** pós-dotfiles
- [x] Criar um subvolume apenas para colocar/organizar os jogos (Steam; Hydra Launcher; Bottles, no caso o Hearthstone)

## BTRFS

### Subdiretórios

| Subvolume | Ponto de Montagem | ID | Descrição |
|-----------|-------------------|-----|-----------|
| `@` | `/` | 256 | Sistema raiz principal |
| `@home` | `/home` | 257 | Diretórios dos usuários |
| `@var_log` | `/var/log` | 258 | Logs do sistema |
| `@var_cache` | `/var/cache` | 259 | Cache de pacotes |
| `@snapshots` | `/.snapshots` | 260 | Armazenamento de snapshots |
| `@games` | `/games` | 269 | Jogos (Steam, Bottles, etc.) |

**Opções de montagem:** `rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2`

### Snapshots

| Data | Nome | Descrição |
|------|------|-----------|
| 07/09/2025 | `clean-install_07-09-2025` | Instalação limpa do sistema |
| 07/09/2025 | `fresh-hyprland_07-09-2025` | Sistema com Hyprland instalado |
| 08/09/2025 | `pre-dotfiles_08-09-2025` | Antes da configuração dos dotfiles |
| 12/09/2025 | `post-dotfiles_12-09-2025` | Após configuração majoritaria dos dotfiles |
