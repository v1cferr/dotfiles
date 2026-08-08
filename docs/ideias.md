# Ideias

Coisas consideradas, referências e o que ainda não virou decisão. O que já virou
está em [historico/](historico/); o que está para fazer, em
[pendencias.md](pendencias.md).

> Quickshell: DECIDIDO — migrei tudo pro Quickshell (ver TODO). Personalizável em QML
> com hot-reload; o Hyprland também virou hot-reload (hyprland.lua via mkOutOfStoreSymlink).
> Para me inspirar: <https://github.com/Misterio77/Foundry>
> Wallpapers Nix: <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
> Temas centralizados: `home/desktop/palette.nix` (`my.theme`). O nix-colors foi descartado (arquivado + base16 limita a 16 cores).

## Filtro de luz azul e cansaço visual

**Se o hyprsunset ganhar transição gradual** (issue *Graduated transition*, aberta em
08/08/2026), os 13 perfis de `home/desktop/hyprsunset.nix` colapsam pra 3 — dia, noite
e madrugada — e a ferramenta interpola. Hoje ele salta seco, e os degraus pequenos são
o que disfarça o salto.

**A ordem de prioridade contra cansaço visual** é a contrária da intuição: reduzir
BRILHO vem antes de temperatura de cor, e modo noturno não substitui brilho adequado.
Foi o que motivou o `system/hardware/ddc.nix` — gamma escurece o sinal, não a luz
emitida. O que falta depois do DDC/CI funcionando:

- **Curva de brilho por horário**, como já existe pra temperatura. Hoje o dim (gamma)
  só começa às 22h; com backlight real dá pra descer antes e mais fundo, sem crushar cor.
- **Bias lighting** — luz atrás do monitor. É a recomendação que mais aparece na
  literatura e a única que não é software: reduz o contraste entre tela e parede escura.
- **PWM**: monitor que escurece por PWM pisca em brilho baixo e piora a fadiga.
  Verificar se os painéis são flicker-free antes de baixar demais o backlight.
