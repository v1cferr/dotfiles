# dotfiles — NixOS + home-manager do v1cferr

Sistema **declarativo** e reprodutível: NixOS (base) e home-manager (dotfiles do
usuário) num único flake. Um `rebuild` aplica sistema **e** usuário de uma vez.

- **Base:** nixpkgs estável `nixos-26.05` + overlay `unstable.*` sob demanda (por pacote).
- **Host ativo:** `nixos-kingston` — NVMe KC3000, btrfs com subvolumes (base p/ impermanência).
- **Boot:** UEFI/**GRUB** com tema minegrub, em **dualboot com o Windows 11** (SSD SanDisk)
  e **Secure Boot** ligado nos dois — chaves próprias via `sbctl`.
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
  packages.nix           LISTA CENTRAL de pacotes de SISTEMA (resgate/base + diagnóstico)

home/                    USUÁRIO (home-manager) — dotfiles + apps de usuário
  default.nix            importa packages.nix + as categorias + stateVersion
  packages.nix           LISTA CENTRAL de apps/CLIs do usuário (sem config própria)
  shell/                 zsh, starship, cli, kitty, git
  desktop/               hypr (+helpers), hyprsunset, lockscreen (+assets), waybar, notifications, theme, xdg
  apps/                  apps COM config própria: dropbox, media, dolphin, flameshot, vscode, mangohud
  services/              cs2-saves-backup, claude-discord-rpc (daemon)

pkgs/                    derivations próprias (fora do nixpkgs) — ex.: claude-code-discord-status
                         expostas em `packages.x86_64-linux` → `nix build .#nxbender`
hosts/                   específico de cada máquina (hostname, discos, monitores, stateVersion)
  nixos-kingston/        ← ÚNICO host (NVMe KC3000, btrfs + subvolumes)
    default.nix          hostname, kernel, montagens extras, my.monitors, stateVersion
    disko.nix            layout de disco declarativo (btrfs + subvolumes)
    services.nix         PAINEL: quais serviços opcionais ESTA máquina liga (my.services.*)
secrets/                 secrets.yaml (sops) + bitwarden-secrets.json
scripts/                 sync-secrets.sh — bash lido por `writeShellApplication` (shellcheck no build)
router/                  espelho do UCI do OpenWrt (router-sync) — visível, não declarável
docs/                    o que NÃO é declarável + o diário do repo (ver docs/README.md)
  regras.md              as 15 regras — a NUMERAÇÃO é API, 70+ comentários citam "regra N"
  pendencias.md          o que está aberto
  historico/<ano>/<mês>  o que foi feito e POR QUÊ (inclui o que foi tentado e RECUSADO)
  ideias.md              considerado, ainda não decidido
  arch-legado.md         capítulo encerrado + como abrir o acervo do Arch
  guias/                 passo a passo de hardware/setup (BIOS, Secure Boot)
  testes/                protocolos de teste reutilizáveis
```

O `README.md` é o único doc da raiz — o resto mora em `docs/`.

## Onde instalar um pacote?

Duas listas centrais, espelhadas: [`system/packages.nix`](system/packages.nix) e
[`home/packages.nix`](home/packages.nix). A decisão por pacote:

1. **Default é o `home/`.** App/CLI seu do dia a dia, sem config → 1 linha em
   [`home/packages.nix`](home/packages.nix) + `rebuild`.
2. App **com config** declarativa (dotfiles / `programs.*`) → módulo próprio no
   `home/` (o pacote e a config andam juntos), ex.: `kitty`, `dolphin`, `flameshot`.
3. Vai pro **`system/`** só se: precisa de **root/resgate** (ex.: `git`/`vim` num
   shell de root), é **driver/serviço**, ou um **serviço de sistema usa** o pacote.

Regra de ouro: *na dúvida, `home/`; só sobe pro `system/` se root ou um serviço precisar.*

`pkgs.foo` = base estável; `pkgs.unstable.foo` = canal unstable (por pacote, via overlay).

## Convenções do repo

1. **Separação `system/` vs `home/`** (ver "Onde instalar um pacote?"). Nível-sistema
   no `system/`; app **e** config de usuário no `home/`. Como o home-manager entra como
   módulo do NixOS (`useGlobalPkgs` + `useUserPackages`), um `rebuild` aplica os dois.
2. **Organização por categoria** — cada assunto numa subpasta com `default.nix`.
3. **Nix = app + config; estado = restic** — saves, prefixos Wine, tokens/sessões de app
   **não** se declaram; vão pro backup.
4. **Uma linha de comentário-resumo por config** em `.nix`/`.lua`/`.conf` — sem poluir.
5. **Validar antes de aplicar** — `nixos-rebuild build` / `nix eval` OK e commits
   atômicos por feature antes do switch.
6. **Opção se DECLARA no `system/`, se DEFINE no `hosts/`** — o `my.*` é a interface
   do repo (`system/services/toggles.nix`, `system/desktop/monitors.nix`); o valor é
   resposta de máquina e mora em `hosts/<host>/`. Opção de hardware sem `default` de
   propósito: host novo que esquecer falha no eval em vez de herdar mentira.

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
  cifrado do `~` (Zen, `.claude`, VSCode, documentos) no **Google Drive**, offsite.
  Ver o conteúdo: `sudo restic-home-gdrive mount /mnt/backup` (pasta por snapshot).
- **SSH** na porta `2222` (root off, `fail2ban` ligado) + **Cloudflare DDNS** mantendo
  `ssh.v1cferr.dev` no IP público atual — acesso de qualquer lugar, sem VPN.

## Reinstalar do zero / migrar de disco

O runbook do cutover SanDisk → Kingston foi **apagado** depois que a migração
aconteceu (01/08/2026) — runbook cumprido é runbook que só mente na próxima vez. Ele
está no histórico, junto com os guias anteriores:

```bash
git log --oneline --all --diff-filter=D -- MIGRACAO-KINGSTON.md INSTALACAO-WINDOWS.md
git show <commit>^:<arquivo>
```

O resumo que **não** envelhece, para a próxima instalação do zero:

- `disko` formata — declarativo e sempre por `/dev/disk/by-id/`, nunca por `sdX`
  (as letras embaralham entre boots; já mudaram duas vezes nesta máquina).
- A **chave age** entra **antes** do `nixos-install`: sem ela o sops não decifra o
  `hashedPasswordFile` e o usuário nasce sem senha. Origem: Bitwarden.
- O `~` vem **disco a disco**, nunca do backup — restic é acervo, não insumo.
- O que não é declarado (`/var/lib`, chaves de host SSH, perfis do NetworkManager)
  atravessa à mão, e é exatamente a lista que a impermanência vai obrigar a declarar.
