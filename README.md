# dotfiles — NixOS + home-manager do v1cferr

Sistema **declarativo** e reprodutível: NixOS (base) e home-manager (dotfiles do
usuário) num único flake. Um `rebuild` aplica sistema **e** usuário de uma vez.

- **Base:** nixpkgs estável `nixos-26.05` + overlay `unstable.*` sob demanda (por pacote).
- **Host ativo:** `nixos-sandisk` — SSD SanDisk (SATA), UEFI/systemd-boot.
- **Máquina:** Intel i5-11400 (microcode) · Intel Arc B580 (driver aberto `xe` + Mesa, sem CUDA).
- **Desktop:** Hyprland (Wayland) via greeter LightDM · PipeWire · teclado ABNT2.

## Uso no dia a dia

Aliases definidos em [`home/shell/zsh.nix`](home/shell/zsh.nix):

```bash
rebuild   # sudo nixos-rebuild switch --flake ~/Projects/GitHub/v1cferr/dotfiles
update    # nix flake update --flake ~/Projects/GitHub/v1cferr/dotfiles  (bump do flake.lock)
gc        # sudo nix-collect-garbage -d  (limpa gerações antigas)
```

Sem `#host`, o `nixos-rebuild` casa o `hostname` atual com o `nixosConfigurations`.
Para um host específico: `sudo nixos-rebuild switch --flake .#<host>`.

## Estrutura

Organizada **por categoria**: cada assunto é uma subpasta com seu próprio
`default.nix` (que importa os módulos dela). Adicionar um módulo = 1 linha no
`default.nix` da categoria; o topo não muda.

```text
flake.nix                inputs (nixpkgs, home-manager, sops, disko, zen-browser…) + overlay + hosts
flake.lock               versões travadas dos inputs

system/                  SISTEMA — comum a todos os hosts (machine-agnostic)
  default.nix            importa as categorias abaixo + packages.nix
  core/                  Nix/flakes, boot, usuários, segredos, locale
  hardware/              CPU/microcode, GPU (Arc B580), áudio (PipeWire), fontes
  net/                   NetworkManager, SSH exposto, fail2ban, DDNS
  desktop/               LightDM, Hyprland, xkb, portal, gnome-keyring
  services/              restic, hooks do Claude Code, Jellyfin/qBittorrent, Ollama/duo
  packages.nix           environment.systemPackages (ferramentas de sistema)

home/                    USUÁRIO (home-manager) — dotfiles + apps de usuário
  default.nix            importa as categorias abaixo + stateVersion
  shell/                 zsh, starship, cli, kitty, git
  desktop/               hypr, hyprsunset, lockscreen (+assets), waybar, notifications, theme, xdg
  apps/                  discord, dropbox, media, dolphin, flameshot, mangohud
  services/              cs2-saves-backup, claude-discord-rpc

pkgs/                    derivations próprias (fora do nixpkgs) — ex.: claude-code-discord-status
hosts/                   específico de cada máquina (hostname, discos, stateVersion)
  nixos-sandisk/         ← ATIVO (SSD SanDisk): default.nix + disko.nix (particionamento)
secrets/                 secrets.yaml (sops) + bitwarden-secrets.json
scripts/                 sync-secrets.sh (Bitwarden → sops) · healthcheck.sh
```

## Convenções do repo

1. **Separação `system/` vs `home/`.** Nível-sistema (serviços, drivers, pacotes de
   root) no `system/`; app **e** config de usuário no `home/` (`programs.*` quando há
   módulo, senão `home.packages`). Como o home-manager entra como módulo do NixOS
   (`useGlobalPkgs` + `useUserPackages`), um `rebuild` aplica os dois. *(Migração dos
   apps GUI de `system/packages.nix` → `home/` em andamento.)*
2. **Organização por categoria.** Cada assunto numa subpasta com `default.nix` (ver
   Estrutura acima).
3. **Uma linha de comentário-resumo por config** em `.nix`/`.lua`/`.conf` — descreve o
   que a linha faz, sem poluir o arquivo.

`pkgs.foo` = base estável; `pkgs.unstable.foo` = canal unstable (por pacote, via overlay).

## Segredos (sops-nix)

Segredos ficam cifrados em [`secrets/secrets.yaml`](secrets/secrets.yaml) — versionados
no git, ilegíveis sem a chave. São decriptados em runtime para `/run/secrets*`. A chave
privada **age** vive em `/var/lib/sops-nix/key.txt`, **fora do git** — é a única coisa a
carregar numa reinstalação (ela sai da senha-mestra do Bitwarden). Base em
[`system/core/secrets.nix`](system/core/secrets.nix).

```bash
nix shell nixpkgs#sops -c sops secrets/secrets.yaml   # editar segredos
```

Guarda hoje: hash da senha do usuário, token do Cloudflare DDNS e (via Bitwarden) a senha
do repositório restic.

## Backup e acesso remoto

- **restic** ([`system/services/restic.nix`](system/services/restic.nix)) — backup
  cifrado do `~` (Zen, `.claude`, VSCode, documentos) no HDD Seagate off-disk.
- **SSH** na porta `2222` (root off, `fail2ban` ligado) + **Cloudflare DDNS** mantendo
  `ssh.v1cferr.dev` no IP público atual — acesso de qualquer lugar, sem VPN.

## Reinstalar do zero

O passo a passo de instalação/migração (formatar o disco via disko, restaurar a chave
age do Bitwarden, `nixos-install`, restaurar o `~`) está preservado no histórico do git:

```bash
git log --oneline --all -- README.md   # localizar o commit do guia de cutover
git show <commit>:README.md            # ver o guia
```
