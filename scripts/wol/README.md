# Wake-on-LAN — desktop (EX-B560M-V5)

Liga o desktop remotamente mandando um *magic packet* pela rede cabeada.

- **NIC:** Realtek RTL8111/8168 (`enp4s0`) — suporta WoL por magic packet.
- **MAC do desktop:** `7c:10:c9:a1:f4:e5`
- **IP fixo (lease):** `192.168.1.10`

## Passos (uma vez)

1. **BIOS** (EX-B560M-V5 → *Advanced → APM Configuration*):
   - `Power On By PCI-E/PCI` → **Enabled** (este é o WoL).
   - `ErP Ready` → **Disabled** (se existir; ErP corta energia do NIC no S5 e mata o WoL).
2. **Confirmar suporte do NIC** (num terminal normal):
   ```sh
   sudo ethtool enp4s0 | grep -i 'Supports Wake-on'
   ```
   Tem que conter **`g`** (magic packet).
3. **Habilitar no SO** (persistente via NetworkManager):
   ```sh
   sudo ~/dotfiles/scripts/wol/deploy.sh
   ```
   No fim ele mostra `Wake-on: g` se ficou ok.
4. **Boot desatendido → sempre Linux** (dualboot Arch/Windows 11 com rEFInd):
   ```sh
   sudo ~/dotfiles/scripts/wol/boot-default-linux.sh
   ```
   Fixa `default_selection "Linux"` no `refind.conf` (casa por substring; nunca
   pega o Windows). Não mexe em Secure Boot. Verifique no próximo boot que o
   rEFInd destaca/auto-boota o Linux. Sem isso, o WoL pode subir no Windows e o
   SSH não fica disponível.

## Acordar o desktop

De **outra** máquina na LAN (o desktop tem que estar na tomada):

```sh
~/dotfiles/scripts/wol/send.sh 7c:10:c9:a1:f4:e5
```

Outras opções para acordar este desktop:
- **Pelo router OpenWrt** (Cudy WR3000, sempre ligado) — ver abaixo. É o
  caminho para acordar **de fora de casa**.
- **Celular:** qualquer app "Wake on LAN" com o MAC acima (na LAN).

## Router OpenWrt (relay do WoL)

O router está sempre ligado, então é ele quem dispara o magic packet na LAN.
Setup já feito (OpenWrt 25.12, apk; reproduzir num reflash):

```sh
# no router (como root / via sudo):
apk update && apk add etherwake
printf '#!/bin/sh\nexec /usr/bin/etherwake -i br-lan 7c:10:c9:a1:f4:e5\n' > /usr/bin/wake-desktop
chmod 0755 /usr/bin/wake-desktop
# rodar sem senha (pra disparar por script/remoto):
printf 'v1cferr ALL=(root) NOPASSWD: /usr/bin/wake-desktop\n' | EDITOR='tee -a' visudo
```

Disparar (de qualquer máquina na LAN, ou via VPN):

```sh
ssh v1cferr@192.168.1.1 sudo -n wake-desktop
# atalho versionado:
~/dotfiles/scripts/wol/wake-via-router.sh
```

### De fora de casa
O desktop está desligado quando você quer acordá-lo, então o SSH 2222 (que
vai pro desktop) não serve — o alvo é o **router**. Opções:
- **WireGuard no OpenWrt** (recomendado): conecta na VPN → `ssh v1cferr@192.168.1.1 sudo -n wake-desktop`. Nada novo exposto além da porta UDP do WG.
- **Expor o SSH do router** (port-forward p/ 192.168.1.1:22, só por chave): mais simples, mais superfície de ataque.

## Notas

- WoL funciona de S3 (suspend), S4 (hibernate) e S5 (shutdown) — desde que a
  BIOS mantenha o NIC energizado (ErP desligado).
- Se o `deploy.sh` não mostrar `Wake-on: g`, o problema é BIOS (passo 1),
  não o SO.
