# dotfiles — NixOS declarativo

Sistema inteiro **declarativo e versionado**: reconstruível em qualquer máquina com um
comando. Host atual: **`nixos-seagate`** (HDD Seagate, Hyprland/Wayland + NVIDIA). Branch de trabalho: **`nixos`**.

> `main` = Arch (produção, intocada) · `arch` = backup congelado.
> Todo o histórico pré-Nix está preservado na tag **`archive/pre-nix-2026-07-16`**
> (`git log archive/pre-nix-2026-07-16` pra navegar).

---

## Instalar um pacote (o caminho fácil)

**1. Ache o nome** em <https://search.nixos.org/packages> ou no terminal:

```bash
nix search nixpkgs spotify
```

**2. Adicione o nome** em `environment.systemPackages`, em `system/default.nix`:

```nix
environment.systemPackages = with pkgs; [
  git
  spotify        # ← só adicionar a linha
  # unstable.foo # ← versão bleeding-edge (canal unstable) — prefixe com `unstable.`
];
```

**3. Aplique:**

```bash
git add -A                                       # flakes só enxergam o que está no git!
sudo nixos-rebuild switch --flake .#nixos-seagate
```

Pronto — o pacote está no PATH. Pra remover, apague a linha e rebuilde.

> **Nunca** `nix profile add` / `nix-env -i` (imperativo — some no rebuild, foge do controle).
> Pra testar **sem instalar**: `nix shell nixpkgs#pkg` abre um shell efêmero com o pacote.

### Detalhes úteis

- **Pacote *unfree*** (spotify, vscode, chrome): já coberto por `nixpkgs.config.allowUnfree = true`.
- **Versão mais nova** que a do canal estável: prefixe com `unstable.` (ex.: `unstable.claude-code`) —
  o overlay do canal `nixos-unstable` já está ligado no `flake.nix`.
- **Configurar** um app (dotfiles, settings) é outra coisa: vai em `home/` (home-manager),
  não em `systemPackages`. Ex.: `home/git.nix`, `home/kitty.nix`.
- **App sem pacote no nixpkgs** (~poucos ex-AUR): derivation própria em `pkgs/`,
  `appimageTools`, ou `nix-init`.

---

## Layout do repo

```text
flake.nix                    # maestro: mkHost + nixosConfigurations.{nixos-seagate, nixos-sandisk, ex-b560m-v5}
flake.lock                   # pins (cápsula do tempo)
system/default.nix           # SISTEMA (COMUM a todos os hosts): pacotes, serviços, desktop…
hosts/                       # o ESPECÍFICO de cada máquina:
  ├─ nixos-seagate.nix       #   HDD atual: hardware-configuration + hostname + mounts
  ├─ nixos-sandisk.nix       #   ALVO do cutover (SSD SanDisk, SATA) — preparado
  ├─ nixos-sandisk-disko.nix #   layout de disco declarativo (disko) da SanDisk
  ├─ ex-b560m-v5.nix         #   alternativa dormente (SSD Kingston, NVMe)
  └─ ex-b560m-v5-disko.nix   #   layout de disco declarativo (disko) do Kingston
hardware-configuration.nix   # scan do HDD (gerado) — não editar
home/                        # USUÁRIO: só CONFIGURA (não instala) — git.nix, hypr.nix, xdg.nix, dropbox.nix…
secrets/                     # segredos sops (secrets.yaml) + índice Bitwarden (bitwarden-secrets.json)
.sops.yaml                   # regras de encriptação (recipient age)
pkgs/                        # derivations próprias ("AUR pessoal")
```

**Sistema + usuário num só rebuild:** o home-manager entra como módulo do NixOS, então
`nixos-rebuild switch` aplica os dois de forma atômica. Regra de ouro do repo:
**pacote = `system/`, configuração = `home/`.** Host novo = criar `hosts/<host>.nix`
(o específico) + 1 linha em `nixosConfigurations` no `flake.nix`; o comum (`system/`) é herdado.

---

## Regras do jogo

1. **Capacidade se declara, estado não.** Bluetooth ligado = config; fone pareado = estado.
   Idem senhas de Wi-Fi, volumes Docker, perfil de navegador.
2. **Flakes só enxergam arquivos rastreados** → `git add` antes de QUALQUER rebuild.
3. **Nada imperativo.** Sem `nix-env`/`nix profile add`. Tudo no config + rebuild.
4. **Segredo nunca em claro no git** (iria legível pra `/nix/store`) → sops-nix.
5. **Base estável `nixos-26.05` + overlay `unstable.*`** por pacote — base previsível,
   bleeding-edge só no que você escolher (prefixando `unstable.`).
6. **⚠️ No Arch, NUNCA dar checkout da branch `nixos` em `~/dotfiles`** — os symlinks do stow
   apontam pro worktree e os configs do Arch vivo sumiriam. Use `git worktree add ~/nixos-wt nixos`.

---

## Estado — o que o declarativo não cobre (sops + restic)

A regra nº 1 diz que **estado não se declara**: senha de Wi-Fi, perfil de navegador, os
arquivos em `~`. É justamente esse lado mutável que deixa um sistema declarativo pela
metade — reconstruo a máquina com um comando, mas não os dados que vivem nela. Duas
ferramentas fecham esse buraco, cada uma no seu registro: **sops** versiona os segredos,
**restic** faz backup dos dados.

**Segredos → `secrets/` (sops-nix).** Senhas e tokens ficam cifrados em
`secrets/secrets.yaml`, versionados no git (ilegíveis sem a chave) e decriptados em runtime
pra `/run/secrets`. A chave **privada** age vive em `/var/lib/sops-nix/key.txt` — FORA do
git, é o que se leva no cutover. Consumidos hoje: senha do usuário (`hashedPasswordFile`),
token do Cloudflare DDNS e a senha do repositório restic.

```bash
# editar/adicionar segredos (encripta sozinho pro recipient do .sops.yaml):
nix shell nixpkgs#sops -c sops secrets/secrets.yaml
git add secrets/secrets.yaml && sudo nixos-rebuild switch --flake .#nixos-seagate
```

**Adicionar segredo sem editar YAML (Bitwarden → sops).** O índice público
`secrets/bitwarden-secrets.json` mapeia nome-no-sops → item-no-Bitwarden. A partir dele o
nix gera os `sops.secrets` sozinho (`system/secrets.nix`) e o comando `sync-secrets` puxa
os valores do Bitwarden e grava cifrado no `secrets.yaml` — o rebuild segue **puro** (sem
`--impure`). Fluxo pra um segredo novo: cadastra no Bitwarden, adiciona uma linha no JSON e:

```bash
export BW_SESSION=$(bw unlock --raw)   # destrava o Bitwarden
sync-secrets                           # Bitwarden → secrets.yaml (cifrado, via sops set)
sudo nixos-rebuild switch --flake .#nixos-seagate
```

Segredos que não vêm do Bitwarden (ex.: o hash de senha do usuário) seguem declarados à
mão no `system/default.nix`.

**Dados de usuário → restic (`system/restic.nix`).** O que não dá pra declarar (seu `~`)
vira backup cifrado: um snapshot diário de `/home/v1cferr` num repositório restic, com poda
automática (7 diários, 4 semanais, 6 mensais) e verificação de integridade a cada run. Cache
e regeneráveis (`node_modules`, `.direnv`, builds, `cache2` do Zen…) ficam de fora. A senha
do repo é o segredo `restic_password` acima — sem ela nada decripta. Hoje o repositório mora
em `/var/backup/restic`, no próprio HDD: é HDD→HDD, então serve de snapshot e de veículo do
cutover (restaurar no destino), mas ainda não protege contra falha do disco — pós-cutover,
apontar `repository` pra um HDD montado torna o backup off-disk de verdade.

```bash
systemctl start restic-backups-home    # backup manual, fora do timer diário
restic-home snapshots                   # listar snapshots (wrapper já traz repo + senha)
restic-home restore latest --target /   # restaurar o snapshot mais recente
```

---

## Cutover — migrar do HDD pro SSD SanDisk (host `nixos-sandisk`)

Instalar na SanDisk é **declarativo** (disko + `nixos-install`): o sistema se reconstrói
inteiro a partir do flake. É **destrutivo pra SanDisk** (que hoje tem Windows, descartável).
O **Arch no Kingston fica intacto** como rede de segurança, e o **HDD Seagate continua
plugado** — é de lá que sai o restore dos seus dados (repo restic).

**Pré-requisitos (ANTES de bootar a live USB):**

1. **Backup do `~` feito** — `restic-home snapshots` deve listar um snapshot recente.
2. **Senha-mestra do Bitwarden** em mãos — é dela que sai a chave age (guardada como nota
   `sops-nix age key (dotfiles)`). Sem a chave age o sops não decripta a senha de login no
   1º boot. (Backup extra: o `.age` no Dropbox + passphrase, ou uma cópia em pendrive.)
3. Pendrive com a **ISO minimal do NixOS** (live USB) + rede por cabo.
4. Nada que você ainda precise na **SanDisk** (o Windows dela será apagado).

**Mapa de discos — sempre por `by-id` (os nomes `sdX`/`nvmeX` EMBARALHAM entre boots!):**

| Disco        | `by-id`                                        | Papel no cutover                        |
| ------------ | ---------------------------------------------- | --------------------------------------- |
| SanDisk 1TB  | `ata-SanDisk_SSD_PLUS_1000GB_22520C801629`     | **ALVO — será FORMATADO**               |
| Seagate 298G | `ata-ST9320423AS_5VH4YZV8`                     | NixOS atual → resgate + fonte do restic |
| Kingston 1TB | `nvme-KINGSTON_SKC3000S1024G_50026B7686B3D2F6` | Arch — PRESERVADO (fallback)            |
| Netac 1TB    | `nvme-NE-1TB_2280_0004382002024`               | Windows (não tocar)                     |

**Passo a passo (bootando pela live USB):**

```bash
# 0. Rede: cabo já pega DHCP.

# 1. Trazer o repo + ferramentas (git e bw vêm via nix-shell no ambiente da ISO)
nix-shell -p git bitwarden-cli
git clone https://github.com/v1cferr/dotfiles ~/dotfiles
cd ~/dotfiles && git checkout nixos

# 2. PARTICIONAR + FORMATAR a SanDisk  ⚠️ APAGA O DISCO (de propósito)
#    (o device está fixado por by-id em hosts/nixos-sandisk-disko.nix)
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#nixos-sandisk
#    → cria GPT (ESP 1G vfat + resto ext4) e monta tudo em /mnt

# 3. Restaurar a CHAVE age (do Bitwarden — só a senha-mestra)
bw login && export BW_SESSION=$(bw unlock --raw)
sudo install -d -m 700 /mnt/var/lib/sops-nix
bw get notes "sops-nix age key (dotfiles)" | sudo tee /mnt/var/lib/sops-nix/key.txt >/dev/null
sudo chmod 600 /mnt/var/lib/sops-nix/key.txt

# 4. Instalar o sistema declarativo
sudo nixos-install --flake .#nixos-sandisk
#    (a senha do v1cferr vem do sops; se pedir senha de root, defina uma temporária)

# 5. Reboot → tira o pendrive → boota na SanDisk (ajuste a ordem de boot na BIOS)
sudo reboot
```

**Pós-cutover (já na SanDisk):**

- Logue com sua senha de sempre (veio do hash no sops), confirme rede/SSH/GPU e rode uma
  vez: `sudo nixos-rebuild switch --flake .#nixos-sandisk`.
- **Restaure o `~` do restic** (o repo vive no HDD Seagate, que segue plugado). De um TTY
  (não logado no desktop, pra não conflitar com arquivos em uso):

  ```bash
  sudo mkdir -p /mnt/seagate
  # ache a partição raiz do Seagate com `lsblk -f` (a ext4 grande) e monte:
  sudo mount /dev/disk/by-id/ata-ST9320423AS_5VH4YZV8-part2 /mnt/seagate
  sudo nix shell nixpkgs#restic -c restic -r /mnt/seagate/var/backup/restic \
    --password-file /run/secrets/restic_password restore latest --target /
  ```

- **Re-pareie o Bluetooth** (o fone é estado): `bluetoothctl` → `pair`/`trust`/`connect`.
- Quando confiar na SanDisk, dá pra remover os hosts `nixos-seagate` e `ex-b560m-v5`
  (Kingston) do `flake.nix`. O Seagate segue bootável como resgate até lá.
- Se algum módulo de kernel faltar: `sudo nixos-generate-config --root /mnt --dir /tmp` no
  instalador e compare o `hardware-configuration.nix` gerado (é a mesma placa, deve bater).

---

## Roadmap

- [x] Flake unificado sistema + home-manager
- [x] sops-nix (senha + DDNS + senha do restic)
- [x] Backup do estado do usuário com restic (snapshot diário cifrado, poda + integridade)
- [x] Segredos automáticos: Bitwarden → sops via `sync-secrets` (puro, sem `--impure`)
- [x] DE leve interino: **XFCE + LightDM** (GNOME pesava no HDD)
- [ ] **Rice Hyprland + Quickshell** — trazer configs da `main`
      (`git checkout main -- hypr/ quickshell/ …`; `mkOutOfStoreSymlink` nos dirs de hot-reload)
- [ ] Homelab: caddy, wireguard, docker/oci-containers
- [ ] NetExtender via `buildFHSEnv`; distrobox Arch (`--nvidia`) como playground pacman/AUR
- [x] **disko + host `nixos-sandisk`** preparados (alvo SanDisk; Arch no Kingston preservado)
- [x] Chave age no **Bitwarden** — restauração no cutover só com a senha-mestra
- [ ] **Cutover**: executar (disko + `nixos-install` na SanDisk) — backup do `~` já feito

### Atritos conhecidos → antídotos

| Atrito                                                  | Antídoto                                                  |
| ------------------------------------------------------- | --------------------------------------------------------- |
| Wheels Python/CUDA assumem FHS (`uv pip install torch`) | `programs.nix-ld.enable = true` (já ligado)               |
| Containers com GPU (open-webui etc.)                    | `hardware.nvidia-container-toolkit.enable = true`         |
| home-manager = symlink read-only (mata hot-reload QML)  | `mkOutOfStoreSymlink` nos dirs quentes                    |
| NetExtender (FHS + daemon, sem pacote)                  | `buildFHSEnv`; reservar um fim de semana                  |
| Saudade do pacman                                       | `nix shell nixpkgs#pkg`, `nix search`, `comma`, distrobox |

---

## Diário

- **2026-07-13** — Branch `nixos` criada e zerada. Esqueleto flake testado em VM na tag
  `nix-flake-skeleton`. Decisões: unstable no host, reescrita à mão pra aprender.
- **2026-07-15** — NixOS 26.05 instalado direto no **HDD Seagate** (host `nixos-seagate`).
  Flake unificado **sistema + usuário** via home-manager como módulo. Layout: `system/`
  (root) + `home/` (usuário), em vez de `hosts/`+`modules/` (indireção só paga com várias máquinas).
- **2026-07-16** — Migração consolidada: **sops-nix** (senha + Cloudflare DDNS), **gh** como
  credential helper do git (push HTTPS por token), troca **GNOME/GDM → XFCE/LightDM** (HDD lento),
  LG ULTRAGEAR como monitor primário, GC reativo por espaço (`min-free`/`max-free`).
  Histórico pré-Nix colapsado na tag `archive/pre-nix-2026-07-16`.
- **2026-07-17** — Preparado o **cutover** pro SSD Kingston. Repo promovido pra **multi-host**
  (`system/` comum + `hosts/{nixos-seagate,ex-b560m-v5}.nix`) e **disko** declarativo (ext4,
  por `by-id`) do Kingston. `nixos-seagate` ficou com `.drv` IDÊNTICO (refactor sem efeito no
  sistema atual). Passo a passo do cutover documentado (seção *Cutover*). Aguarda só o backup
  dos dados do Arch/Kingston pro SSD antes de executar.
- **2026-07-18** — Fechado o lado do **estado** e preparado o cutover pra SanDisk. **Zen**
  como navegador padrão declarativo (`home/xdg.nix`); **restic** com 1º snapshot do `~`
  (16.6 GiB); **Dropbox** declarativo (`services.dropbox`, cofre do Obsidian); **Bitwarden**
  (desktop + CLI) como gerenciador de senhas; automação **Bitwarden → sops** via `sync-secrets`
  (puro, sem `--impure`, índice em `secrets/bitwarden-secrets.json`); **chave age guardada no
  Bitwarden** (restauração só com a senha-mestra); Bluetooth com relato de bateria do fone.
  Trocado o alvo do cutover: **host `nixos-sandisk`** (SanDisk SATA) no lugar do Kingston,
  preservando o Arch como fallback. Seção *Cutover* reescrita pro fluxo real.
