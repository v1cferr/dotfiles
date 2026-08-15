# Teste: MTU do túnel + Moonlight pelo WireGuard

**Onde:** UFSCar, no **notebook da FAI**, com o WireGuard conectado.
**Por quê:** de casa é impossível — não há interface WireGuard nesta máquina (o
túnel termina no ROTEADOR), então qualquer ping para `10.10.10.1` sai pelo cabo e
mede a LAN, não o túnel. O sinal de teste inválido é latência de ~0,3 ms.

Protocolo reutilizável: vale toda vez que mudar MTU, `packet_size` ou trocar de
cliente.

## 1. A MTU do túnel (resposta direta)

No notebook, com a VPN no ar:

```sh
ip link show | grep -A1 -i wg
```

O `mtu N` ali é a resposta. WireGuard costuma ficar em **1420**.

## 2. Confirmar fim a fim (o que importa)

O número acima é da interface; o que decide é o caminho INTEIRO — túnel, roteador,
LAN, até o host do Sunshine:

```sh
ping -M do -s 1372 192.168.1.10
```

- passou → suba: `1392`, `1400`, `1412`
- falhou com *"message too long"* → desça

**Maior `-s` que passar + 28** (cabeçalhos IP+UDP) = MTU real do caminho.

Anote o número. Latência de vários milissegundos confirma que o teste é válido;
0,3 ms significa que você não está passando pelo túnel.

## 3. Moonlight de verdade

Parear e streamar do notebook. Observar:

- a sessão passa de 2 minutos?
- há desconexão em ~4 s? → sintoma clássico de pacote estourando a MTU

Depois, em casa: `moonlight-stats 1` mostra duração das sessões do dia.

## 4. O que fazer com o resultado

Hoje `packet_size = 1024` em `system/services/sunshine.nix`. Foi calibrado para a
MTU **1280** da antiga `tailscale0`, deixando 256 bytes de folga. Com o WireGuard
em ~1420 provavelmente sobra espaço, e pacote maior = menos overhead por frame.

⚠️ **Não suba direto para o teto.** Estourar a MTU faz o WireGuard descartar em
SILÊNCIO — sem ICMP, sem log. O host streama normal, o cliente recebe pela metade,
não remonta frame e cai em ~4 s. Foi exatamente o bug de 29/07/2026, e custou um
debug longo justamente por não dar erro em lugar nenhum.

Suba com a mesma folga proporcional que já funcionou e valide com sessão real
antes de commitar.

## Contexto

- A `fai-workstation` **é** peer (`10.10.10.5/32`), mas é Ubuntu server sem
  interface gráfica — serve para o passo 2, não para o 3.
- Peers existentes: `notebook` (`.2`), `celular` (`.3`), `fai-workstation` (`.5`).
- Medido em 08/08/2026: UDP 51820 da rede da FAI **chega** no roteador (contador
  do `Allow-WireGuard` foi de 0 → 3). O caminho existe.
