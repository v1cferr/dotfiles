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
- [ ] Trocar <https://wttr.in/S%C3%A3o+Carlos> pela API do Google Weather <https://developers.google.com/maps/documentation/weather>
- [ ] Adicionar as configurações do VSCode (dotfiles) nesse repositório <https://github.com/v1cferr/dotfiles> (meu perfil é bem especifico)
- [ ] Adicionar algum Clipboard Manager <https://wiki.hypr.land/Useful-Utilities/Clipboard-Managers/>
- [ ] Verificar pq o cursor tá bugando na hora que o **Hyprsunset** ativa (fica com uma coloração mais destacada que o resto da tela)
- [ ] Adicionar uma verificação e sumir o `hyprland/window` quando não tiver nenhuma aplicação rodando em algum workspace (para não poluir a Waybar)
- [ ] Personalizar meu **fastfetch** e colocar o simbolo da Alliance (WoW) invés da logo do Arch
  - <https://chatgpt.com/share/68b853fd-14e8-800e-ac3a-ac8b9fa01a24>
- [ ] Adicionar o dia da semana (*e.g.: Seg 03/09/2025*) na topbar central

### Stylish

- [X] Reduzir apenas um pouco a opacidade e blur das mini-pilulas na **Waybar** para ter simetria com o style das próprias janelas no **Hypr**
  - {be02e75873a62572fb6dde5199f23efc0649c580}

### Menos importantes

## Concluidos

- [x] Verificar pq o cursor está bugado graficamente (fica cinza escuro sem textura) ao rodar o Hearthstone pelo `bottles-cli run -b "Battle.net" -p "Battle.net"`
  - Adicionado `xwayland { force_zero_scaling = true }` no hyprland.conf
- [x] Aumentar a duração das notificações (10 segundos para dar tempo de ler)
- [x] Configurar e documentar o [Hyprsunset](./hypr/.config/hypr/hyprsunset.conf)
- [X] Aumentar levemente o gap entre as janelas quando estão uma ao lado da outra
  - {deaef8161b723c0b4bc5b314331a17bd8ea3b75c}
- [x] Melhorar essa [Waybar](./waybar/) e deixar do jeito que eu quero
  - [x] Deixar o bg transparent (da propria waybar)
  - [x] Sistema de pílulas com ícones do mechabar
  - Inspirações:
    - <https://github.com/sejjy/mechabar>
