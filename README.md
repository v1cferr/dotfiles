# dotfiles — NixOS + home-manager do v1cferr

Sistema **declarativo** e reprodutível: NixOS (base) e home-manager (dotfiles do
usuário) num único flake. Um `rebuild` aplica sistema **e** usuário de uma vez.

- **Base:** nixpkgs estável `nixos-26.05` + overlay `unstable.*` sob demanda (por pacote).
- **Host ativo:** `nixos-sandisk` — SSD SanDisk (SATA), UEFI/systemd-boot.
- **Máquina:** MOBO EX-B560M-V5 · Intel (microcode) · NVIDIA RTX 3050 (driver aberto).
- **Desktop:** Hyprland (Wayland) via greeter LightDM · PipeWire · teclado ABNT2.

## Uso no dia a dia

Aliases definidos em [`home/zsh.nix`](home/zsh.nix):

```bash
rebuild   # sudo nixos-rebuild switch --flake ~/Projects/GitHub/v1cferr/dotfiles
update    # nix flake update --flake ~/Projects/GitHub/v1cferr/dotfiles  (bump do flake.lock)
gc        # sudo nix-collect-garbage -d  (limpa gerações antigas)
```

Sem `#host`, o `nixos-rebuild` casa o `hostname` atual com o `nixosConfigurations`.
Para um host específico: `sudo nixos-rebuild switch --flake .#<host>`.

## Estrutura

```text
flake.nix                inputs (nixpkgs, home-manager, sops, disko, zen-browser) + hosts
flake.lock               versões travadas dos inputs
hardware-configuration.nix

system/                  SISTEMA — comum a todos os hosts (machine-agnostic)
  default.nix            boot, rede, NVIDIA, áudio, Hyprland, usuário, SSH, PACOTES (lista única)
  restic.nix             backup cifrado do estado do usuário
  secrets.nix            gera sops.secrets a partir do Bitwarden + sync-secrets
  secrets.nix / sync-secrets.sh

home/                    USUÁRIO (home-manager) — só CONFIGURA (não instala pacote)
  default.nix            imports dos módulos por app + stateVersion
  git · zsh · starship · kitty · hypr · waybar · theme · xdg · dropbox · dolphin · flameshot

hosts/                   específico de cada máquina (hostname, discos, stateVersion)
  nixos-sandisk.nix      ← ATIVO (SSD SanDisk); *-disko.nix = particionamento declarativo
  nixos-seagate.nix      instalação anterior (HDD Seagate)
  ex-b560m-v5.nix        alternativa dormente (SSD Kingston NVMe)

pkgs/                    derivations próprias ("AUR pessoal") — placeholder por ora
secrets/                 secrets.yaml (sops) + bitwarden-secrets.json
scripts/                 cutover-sandisk.sh (instalação) · restore-home.sh (restaura ~ do restic)
```

## Duas regras do repo

1. **Pacote se instala só no `system/`** (`environment.systemPackages`, lista única —
   máquina de um usuário só). O `home/` **não instala nada**, apenas configura
   settings/dotfiles. `pkgs.foo` = base estável; `pkgs.unstable.foo` = canal unstable.
2. **Uma linha de comentário-resumo por config** em `.nix`/`.lua`/`.conf` — descreve o
   que a linha faz, sem poluir o arquivo.

## Segredos (sops-nix)

Segredos ficam cifrados em [`secrets/secrets.yaml`](secrets/secrets.yaml) — versionados
no git, ilegíveis sem a chave. São decriptados em runtime para `/run/secrets*`. A chave
privada **age** vive em `/var/lib/sops-nix/key.txt`, **fora do git** — é a única coisa a
carregar numa reinstalação (ela sai da senha-mestra do Bitwarden).

```bash
nix shell nixpkgs#sops -c sops secrets/secrets.yaml   # editar segredos
```

Guarda hoje: hash da senha do usuário, token do Cloudflare DDNS e (via Bitwarden) a senha
do repositório restic.

## Backup e acesso remoto

- **restic** ([`system/restic.nix`](system/restic.nix)) — backup cifrado do `~`
  (Zen, `.claude`, VSCode, documentos). Restaurar: `sudo ./scripts/restore-home.sh`.
- **SSH** na porta `2222` (root off, `fail2ban` ligado) + **Cloudflare DDNS** mantendo
  `ssh.v1cferr.dev` no IP público atual — acesso de qualquer lugar, sem VPN.

## Reinstalar do zero

O passo a passo de instalação/migração (formatar o disco via disko, restaurar a chave
age do Bitwarden, `nixos-install`, restaurar o `~`) está preservado no histórico do git:

```bash
git log --oneline --all -- README.md   # localizar o commit do guia de cutover
git show <commit>:README.md            # ver o guia
```

O script [`scripts/cutover-sandisk.sh`](scripts/cutover-sandisk.sh) automatiza a instalação.
