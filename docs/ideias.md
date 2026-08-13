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
emitida. A curva de brilho por DDC/CI foi FEITA e REVERTIDA — funcionava, mas só no monitor
principal, e a TV do HDMI não tem caminho automático. Ver o histórico de agosto. O que
segue em aberto:

- **Gamma progressivo a partir das 18h** — o passo seguinte se a curva de cor não bastar,
  e é ele que finalmente aplicaria a prioridade acima. Em 13/08/2026 a curva pós-18h
  desceu ~200–400K por degrau (2ª descida) e o eixo do BRILHO foi deixado de fora de
  propósito: o dim automático por gamma existiu e foi revertido em 08/08 junto com o DDC.
  ⚠️ A curva de Kelvin chegou perto do fundo útil — já atravessa os ~3200K em que a cor
  estraga mídia —, então continuar descendo K piora a cor sem alívio proporcional. Se o
  incômodo voltar, o ajuste é gamma, não mais laranja.
- **Bias lighting** — luz atrás do monitor. É a recomendação que mais aparece na
  literatura e a única que não é software: reduz o contraste entre tela e parede escura.
- **PWM**: monitor que escurece por PWM pisca em brilho baixo e piora a fadiga.
  Verificar se os painéis são flicker-free antes de baixar demais o backlight.

## NetBird: contingência de CGNAT, não substituto

<https://github.com/netbirdio/netbird> — WireGuard com plano de controle: descoberta de
peers, NAT traversal automático, ACL por dispositivo e SSO. Avaliado em 10/08/2026, no
mesmo dia em que o acesso direto do Moonlight entrou.

**DECISÃO: ficar só com o WireGuard do roteador. Não trocar, e não rodar os dois.**

O enquadramento que importa não é "trocar ou não" — é que o desenho atual repousa numa
premissa única: **a Alcans dá IP público de verdade**. Port-forward, WireGuard no
roteador e DDNS dependem os três disso. Se mudar, caem JUNTOS, no mesmo minuto. O NetBird é o
plano para esse dia, e esta análise existe para não ser refeita sob pressão.

### Por que não agora

- **Exige agente em toda máquina**, e é justamente o que foi recusado: o notebook da FAI
  já roda nxBender + openconnect, e o agente do NetBird gerencia rota dinamicamente —
  mesma classe de conflito, mais difícil de depurar que um `wg-quick` estático.
- **Reintroduz o relay.** Ele cai pra Relay/TURN quando o P2P falha, que é o DERP do
  Tailscale com outro nome — a razão da saída do Tailscale em 08/08. E na rede da FAI,
  que descarta SYN-ACK, falha de P2P é o cenário PROVÁVEL: relayaria justamente lá.
- **O roteador não pode ser o servidor.** O management pede "1 CPU e 2 GB"; o WR3000 tem
  128 MB de RAM e ~1,3 MB de flash livre. O agente roda em OpenWrt, o plano de controle
  não.
- **Auto-hospedar cria dependência circular:** management + signal + relay iriam pro PC,
  que é a máquina que se quer alcançar. Hoje não existe esse laço — o roteador é aparelho
  separado e sempre ligado. Usar a nuvem deles resolve o círculo readicionando o terceiro.

### O que ele resolveria de verdade (e por isso fica anotado)

1. **CGNAT** — o gatilho. Com relay, sobrevive ao que hoje mataria tudo.
2. **Adicionar peer sem editar UCI à mão.** Hoje é SSH no roteador; o `router-sync` é
   pull-only. Atrito real.
3. **ACL por dispositivo.** Hoje a regra do Sunshine confia na faixa `10.10.10.0/24`
   INTEIRA — celular, notebook e workstation têm exatamente o mesmo acesso. Esta é uma
   limitação de verdade do desenho atual, independente de CGNAT.

### Gatilho para reabrir

O IP público de casa deixar de responder de fora. Teste que não mente (ponto externo
independente, nunca de dentro da LAN — a operadora faz hairpin):

```sh
curl -s "https://check-host.net/check-tcp?host=<ip>%3A2222&max_nodes=3" \
  -H "Accept: application/json"
```

## "Tudo no roteador": o que já é, e o que não pode ser

Ideia do dono (10/08/2026): concentrar serviço no roteador para nada parar quando o PC
cair (queda de energia e afins).

**BOA NOTÍCIA: a camada de ACESSO já é exatamente isso.** Rodam no roteador e não dependem
do PC — WireGuard (`wg0`, é ele o servidor), DHCP, DNS com adblock-fast e https-dns-proxy,
firewall/SQM, e o Wake-on-LAN (`/usr/bin/wake-desktop`). O PC pode estar desligado que a
VPN sobe e a rede de casa funciona.

**O que NÃO pode migrar:** Jellyfin, Sunshine, Caddy, qBittorrent e Ollama. Não é questão
de vontade — são 128 MB de RAM e 1,3 MB de flash livre. Streaming de tela e transcode de
mídia não cabem em ordem de grandeza nenhuma.

⚠️ **E o gargalo do cenário "acabou a luz" NÃO é o roteador — é o PC voltar sozinho.**
Isso é BIOS (*Restore on AC Power Loss* = Power On), não Nix, e não é declarável neste
repo. O WoL NÃO substitui: depois de um corte real de energia a NIC perde o estado armado
por `ethtool`, e só volta se a própria BIOS mantiver o wake habilitado. Ordem certa de
atacar: (1) BIOS religa sozinho, (2) WoL como resgate para desligamento normal, (3) nobreak
no roteador+modem se a intenção for manter a internet DURANTE a queda — mas isso não acende
o PC, porque ele não está no nobreak.

⚠️ `router/uci/etherwake.conf` é CONFIG MORTA: `name='example'`, `mac='11:22:33:44:55:66'`
— placeholder de fábrica do app LuCI, nunca preenchido. Quem funciona é o
`/usr/bin/wake-desktop`, com o MAC embutido. Não confiar na tela do LuCI.
