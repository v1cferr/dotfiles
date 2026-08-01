# Migração SanDisk → Kingston (cutover)

Runbook do cutover: sair do `nixos-sandisk` (SSD SATA, ext4) e chegar no
`nixos-kingston` (NVMe KC3000, btrfs) **com o mesmo estado, os mesmos segredos e
tudo funcionando**. Escrito em 01/08/2026, para ser seguido no console do live USB.

> **Este arquivo tem prazo de validade.** Depois que o Kingston estiver validado e o
> SanDisk virar Windows, apague-o — runbook desatualizado é pior que runbook nenhum.

**A rede de segurança:** o SanDisk continua bootável do começo ao fim. Se qualquer
passo der errado, você escolhe o outro disco no menu da firmware (F8 na EX-B560M-V5)
e volta para o sistema de hoje, intacto. O plano só fica irreversível no dia em que
você formatar o SanDisk para o Windows — que **não** é hoje.

---

## Referência rápida

|                        |                                                                    |
| ---------------------- | ------------------------------------------------------------------ |
| Kingston (destino)     | `/dev/disk/by-id/nvme-KINGSTON_SKC3000S1024G_50026B7686B3D2F6`     |
| SanDisk (origem)       | UUID `d0392422-6a6c-4c36-8ff4-e6eda25ae487`                        |
| Seagate (backup)       | UUID `85788f24-b8a0-4c3e-af4f-8af1f8b52147`                        |
| Repo no SanDisk        | `/mnt/sd/home/v1cferr/Projects/GitHub/v1cferr/dotfiles`            |
| Sistema pré-construído | `/mnt/sd/home/v1cferr/kingston-system` (symlink p/ o `/nix/store`) |
| Volume da travessia    | `/home` = 403 G · `/var/lib` + `/etc` = ~500 M                     |

**Fora do escopo de propósito:** `/srv/media` (130 G de biblioteca Jellyfin) e
`/var/lib/jellyfin`. Ambos re-obteníveis; o serviço é declarativo e sobe sozinho.

---

## Fase 0 — Antes de reiniciar (no sistema atual)

Tudo aqui roda no NixOS do SanDisk, ainda funcionando.

### 0.1 Confirme que o acervo do Arch está salvo

O Kingston vai ser **apagado**. O home do Arch que mora nele só existe nos backups.

```bash
sudo restic-arch-kingston snapshots         # Drive
sudo restic-arch-kingston-local snapshots   # Seagate
```

Os dois têm que listar um snapshot. Se algum não listar, **pare aqui**.

### 0.2 Garanta o sistema pré-construído e o gcroot

```bash
cd ~/Projects/GitHub/v1cferr/dotfiles
nix build --out-link ~/kingston-system \
  .#nixosConfigurations.nixos-kingston.config.system.build.toplevel
readlink -f ~/kingston-system
```

Isso constrói o sistema do Kingston no `/nix/store` do SanDisk **e** o marca como
gcroot, para o `gc` não apagá-lo antes da hora. O instalador vai copiar do disco ao
lado em vez de baixar tudo da internet.

### 0.3 Empurre o repo pro GitHub

Não é obrigatório (o instalador lê o repo do SanDisk), mas é seguro de graça: se algo
acontecer com o SanDisk no meio do caminho, a config não vai junto.

```bash
git status --short     # tem que estar limpo
git push
```

### 0.4 Deixe o pendrive pronto

Já gravado. Se precisar refazer:

```bash
sudo umount /run/media/v1cferr/* 2>/dev/null
sudo dd if=~/Downloads/nixos-minimal-26.05.6503.21ea275a7c46-x86_64-linux.iso \
  of=/dev/disk/by-id/usb-hp_v165w_00248121AB99EE30E00065B2-0:0 \
  bs=4M status=progress oflag=sync
```

---

## Fase 1 — Bootar o live USB

1. Reinicie e entre no menu de boot (**F8** na EX-B560M-V5).
2. Escolha o pendrive em modo **UEFI** (não Legacy/CSM).
3. O NixOS minimal loga sozinho como usuário `nixos`, sem senha.

```bash
sudo -i        # daqui pra frente, tudo como root
```

### Rede

Você está no cabo (`enp7s0`), então o DHCP resolve sozinho. Confirme:

```bash
ping -c3 cache.nixos.org
```

Sem rede, o `disko` não baixa e nada anda. Se falhar: `systemctl restart dhcpcd`.

---

## Fase 2 — Montar o SanDisk

O SanDisk é a fonte de tudo: o repo, o sistema pré-construído, a chave age e o `/home`.

```bash
mkdir -p /mnt/sd
mount /dev/disk/by-uuid/d0392422-6a6c-4c36-8ff4-e6eda25ae487 /mnt/sd

# confirme que é o disco certo
ls /mnt/sd/home/v1cferr/Projects/GitHub/v1cferr/dotfiles/flake.nix
ls -l /mnt/sd/var/lib/sops-nix/key.txt
```

Os dois têm que existir. Se não existirem, você montou o disco errado — desmonte e
confira com `lsblk -f`.

> **Sobre clonar o repo em vez de usar o do SanDisk:** o repo é público, então
> `git clone -b nixos https://github.com/v1cferr/dotfiles` funciona no instalador. Mas
> **isso não substitui montar o SanDisk** — os 403 G do `/home`, a chave age e a
> closure pré-construída só existem lá. Use o clone apenas como plano B se o repo do
> SanDisk estiver ilegível; e leia o aviso da Fase 5 sobre o input privado antes.

---

## Fase 3 — Formatar o Kingston ⚠️ DESTRUTIVO

**Este é o passo sem volta para o disco Kingston.** Só siga se a Fase 0.1 passou.

```bash
nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake path:/mnt/sd/home/v1cferr/Projects/GitHub/v1cferr/dotfiles#nixos-kingston
```

> O `path:` em vez de `.` é proposital: no instalador você é root e o repo é do uid
> 1000; a proteção de *dubious ownership* do git faz o fetcher do nix falhar. O `path:`
> ignora o git e lê o diretório direto — o que também faz funcionar com arquivo não
> commitado.

### Confira o layout antes de seguir

```bash
findmnt -R /mnt
btrfs subvolume list /mnt
```

Você tem que ver `/mnt` (btrfs), `/mnt/boot` (vfat), `/mnt/home`, `/mnt/nix`,
`/mnt/persist`, `/mnt/var/log`, `/mnt/swap` — e os seis subvolumes `@ @home @nix
@persist @log @swap`.

---

## Fase 4 — A chave age ⚠️ NÃO PULE

Sem isto, o sops não decripta nada no primeiro boot. E como o
`v1cferr_password_hash` é um segredo com `neededForUsers`, **seu usuário fica sem
senha** e você se tranca para fora do sistema recém-instalado.

```bash
mkdir -p /mnt/var/lib/sops-nix
cp /mnt/sd/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
chmod 600 /mnt/var/lib/sops-nix/key.txt

# confirme
head -c 20 /mnt/var/lib/sops-nix/key.txt   # deve começar com AGE-SECRET-KEY-1
```

> **Plano B se o SanDisk não estiver acessível:** a mesma chave está no Bitwarden, na
> secure note `sops-nix age key (dotfiles)`. Confira que a pública derivada bate com o
> recipient do `.sops.yaml`:
> `age132kmspxjsqzc3nnd6407svq744ju4q6vl85hq2v02pgqc2yf7caq03plfn`

---

## Fase 5 — Instalar o sistema

O sistema já está construído no store do SanDisk. Copia de lá em vez de baixar:

```bash
SYS=$(readlink -f /mnt/sd/home/v1cferr/kingston-system)
echo "$SYS"    # nixos-system-nixos-kingston-26.05...

nix --extra-experimental-features 'nix-command flakes' \
  copy --no-check-sigs --from "local?root=/mnt/sd" --to /mnt "$SYS"

nixos-install --root /mnt --system "$SYS" --no-root-passwd
```

O `--no-root-passwd` é de propósito: root não tem senha nesta config, e o seu usuário
vem do sops. Se o instalador perguntar senha de root, algo saiu do script.

> **Use este caminho, não o `--flake`.** Não é só velocidade: o `--system` instala uma
> closure **já construída** e não avalia flake nenhum. O caminho `--flake` avaliaria, e
> aí o nix tentaria buscar o input `duo-streak-daemon`, que é um **repo PRIVADO por
> `git+ssh`** (`flake.nix` linha 48). O instalador não tem sua chave SSH → falha de
> autenticação no meio do cutover, com o Kingston já formatado.

### Se precisar mesmo do `--flake` (plano C)

Só se a closure pré-construída não existir. Leve a chave SSH junto:

```bash
mkdir -p /root/.ssh
cp /mnt/sd/home/v1cferr/.ssh/id_ed25519 /root/.ssh/
chmod 600 /root/.ssh/id_ed25519

nixos-install --root /mnt \
  --flake path:/mnt/sd/home/v1cferr/Projects/GitHub/v1cferr/dotfiles#nixos-kingston \
  --no-root-passwd
```

Sem a chave, isso falha. Com ela, funciona mas baixa tudo da internet.

---

## Fase 6 — Levar o estado

Aqui é o que transforma "instalado" em "igual ao de ontem". Nada disto é declarativo,
por definição: é justamente o estado que a **regra 6** manda não declarar.

O `rsync` pode não estar no ISO mínimo. Se `rsync --version` falhar:

```bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#rsync
```

### 6.1 O `/home` — 403 G, o grosso do tempo

```bash
rsync -aHAX --info=progress2 /mnt/sd/home/ /mnt/home/
```

`-H` preserva hardlink, `-A` ACL, `-X` xattr. Disco a disco, espere 15–25 min.

> **Por que copiar antes do primeiro boot:** o home antigo já contém os symlinks que o
> home-manager gerou, apontando para caminhos do `/nix/store`. Como o Kingston roda o
> **mesmo** flake, as derivações têm o mesmo hash e os symlinks continuam válidos. O
> HM ativa em cima de um home já correto e não reclama de arquivo que ele "ia
> gerenciar e já existe".

### 6.2 Estado de serviço em `/var/lib`

```bash
mkdir -p /mnt/var/lib
for d in nixos NetworkManager AccountsService bluetooth fail2ban \
         qBittorrent cloudflare-dyndns lightdm-data; do
  [ -e "/mnt/sd/var/lib/$d" ] && rsync -aHAX "/mnt/sd/var/lib/$d" /mnt/var/lib/
done
```

**`/var/lib/nixos` é o mais importante da lista** e o menos óbvio: guarda o
`uid-map`/`gid-map`, ou seja, quais UIDs o NixOS atribuiu aos usuários de serviço. Sem
ele, o Jellyfin (ou o qBittorrent) pode nascer com outro UID e perder acesso aos
arquivos que ele mesmo criou.

Opcionais, decida caso a caso:

```bash
# modelos do Ollama — vários GB, re-baixáveis com `ollama pull`
rsync -aHAX /mnt/sd/var/lib/ollama /mnt/var/lib/

# volumes do Docker (banco do duo-streak-daemon)
rsync -aHAX /mnt/sd/var/lib/docker /mnt/var/lib/
```

### 6.3 Chaves de host SSH e conexões do NetworkManager

```bash
cp -a /mnt/sd/etc/ssh/ssh_host_* /mnt/etc/ssh/
mkdir -p /mnt/etc/NetworkManager
rsync -aHAX /mnt/sd/etc/NetworkManager/system-connections /mnt/etc/NetworkManager/
```

As chaves de host evitam que todo cliente seu grite *REMOTE HOST IDENTIFICATION HAS
CHANGED* ao acessar `ssh.v1cferr.dev`. O `system-connections` carrega os perfis de
rede **com os segredos** — inclusive a VPN da UFSCar.

### 6.4 Tailscale — uma escolha

O Tailscale registra o nó pelo hostname, que muda de `nixos-sandisk` para
`nixos-kingston`. Duas saídas:

**A) Nó novo (recomendado).** Não copie nada. O Kingston entra na tailnet como nó
novo, usando o authkey do sops. Depois de validar, apague o `nixos-sandisk` no admin
do Tailscale. Clientes que apontam pro nome antigo precisam ser repontados.

**B) Herdar a identidade.** `rsync -aHAX /mnt/sd/var/lib/tailscale /mnt/var/lib/`
mantém o node key, então IP e ACLs seguem os mesmos. **Só faça isso se não for ligar
os dois sistemas ao mesmo tempo** — dois nós com a mesma chave brigam.

---

## Fase 7 — Reiniciar no Kingston

```bash
umount -R /mnt/sd
umount -R /mnt
reboot
```

Tire o pendrive. No menu de boot (**F8**), escolha o **Kingston**.

### Validação — rode tudo isto no primeiro boot

```bash
# 1. login gráfico funciona? (senha vinda do sops — se falhar, foi a Fase 4)

# 2. nenhum serviço quebrado
systemctl --failed

# 3. os dez segredos decriptaram
ls /run/secrets/

# 4. filesystem certo, subvolumes montados
findmnt -t btrfs
btrfs filesystem usage /

# 5. swap ativo (o do disko, em /swap/swapfile)
swapon --show

# 6. rede e tailnet
tailscale status

# 7. o home veio inteiro
du -sh ~ && ls ~/Projects/GitHub/v1cferr/dotfiles

# 8. reconcilia a config (deve ser no-op ou quase)
rebuild
```

O `rebuild` sem `#host` casa o hostname atual (`nixos-kingston`) com o
`nixosConfigurations` sozinho — seu alias continua igual.

Se tudo passou, **você chegou.** O sistema é o mesmo de ontem, no disco rápido.

---

## Fase 8 — Depois, sem pressa

Só quando o Kingston tiver rodado alguns dias sem susto:

1. **Reponha a mídia** do Jellyfin em `/srv/media/media` e refaça a biblioteca.
2. **Apague o nó `nixos-sandisk`** no admin do Tailscale (se escolheu a opção A).
3. **Confira que o restic do home vivo está rodando** no host novo:
   `systemctl status restic-backups-home` e `sudo restic-home snapshots`.
   Enquanto ele não tiver pego a máquina nova, você **não** tem backup do dia a dia.
4. **Desligue o arquivamento do Arch**: `arch-kingston-archive = false` em
   [`system/services/toggles.nix`](system/services/toggles.nix) e apague
   `system/services/restic-arch-kingston.nix`. Os repos no Drive e no Seagate
   sobrevivem sozinhos — só a senha do Bitwarden é necessária pra restaurar.
5. **Remova o mount transitório** `/mnt/sandisk-old` de
   [`hosts/nixos-kingston/default.nix`](hosts/nixos-kingston/default.nix) — quando o
   SanDisk virar Windows, o UUID muda e aquele bloco passa a mentir.
6. **Aí sim**, Windows 11 no SanDisk. Com o **Kingston desconectado fisicamente** (ou
   desabilitado na BIOS) durante a instalação: o instalador do Windows se apossa da
   ESP que encontrar. Dois discos, duas ESPs, escolha no menu da firmware.

E finalmente: apague este arquivo.

---

## Se der errado

**Em qualquer ponto até a Fase 7**, o SanDisk está intacto e bootável. F8 no boot,
escolha o SanDisk, e você está de volta ao sistema de hoje. Nada foi perdido — o único
disco alterado foi o Kingston, cujo conteúdo já está em dois backups verificados.

| Sintoma                         | Causa provável                                                     |
| ------------------------------- | ------------------------------------------------------------------ |
| Boot sem senha de usuário       | Fase 4 pulada — a chave age não chegou em `/mnt/var/lib/sops-nix/` |
| `/run/secrets/` vazio           | Idem, ou permissão errada na chave (tem que ser `600`)             |
| `dubious ownership` no nix      | Faltou o `path:` no `--flake`                                      |
| Kingston não aparece no boot    | ESP não criada — confira a Fase 3 com `findmnt -R /mnt`            |
| Serviço sem acesso aos arquivos | `/var/lib/nixos` não foi copiado (uid/gid remapeados)              |
| Cliente SSH acusa host mudado   | Fase 6.3 pulada — chaves de host não vieram                        |
| `Permission denied (publickey)` durante o install | Usou `--flake`; o input `duo-streak-daemon` é privado. Use o `--system` da Fase 5 |
