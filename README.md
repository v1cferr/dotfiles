# NixOS do zero — plano & diário de bordo

> **Branch `nixos`**: reconstrução 100% declarativa a partir da ISO minimal, escrita à mão.
> **`main`** = Arch (produção, intocada) · **`arch`** = backup congelado da main.
> Todo o histórico anterior está preservado no git — o esqueleto flake **testado em VM**
> (flake check verde, Hyprland bootando) vive na tag `nix-flake-skeleton`:
> `git checkout nix-flake-skeleton -- nix/` traz o gabarito quando travar.

## Objetivo

Sistema inteiro declarativo e versionado (GitHub + redundância local), reconstruível em
qualquer máquina/disco com um comando, mantido até 2032+. Rice Hyprland + Quickshell
preservado. Curadoria total: só entra o que for declarado conscientemente — o acúmulo
de ~1 ano de Arch não migra por inércia.

## Regras do jogo

1. **Capacidade se declara, estado não.** Bluetooth ligado = config; fone pareado = estado
   (`/var/lib/bluetooth`). Idem senhas de Wi-Fi, volumes Docker, perfil de navegador.
2. **Flakes só enxergam arquivos rastreados** → `git add` antes de QUALQUER rebuild.
3. **Canal `nixos-unstable`** no flake (bleeding edge, estilo Arch). A ISO de instalação
   pode ser a estável (26.05) — o canal muda no flake depois.
4. **Segredo nunca rastreado em claro** (vai legível pra `/nix/store`) → sops-nix quando
   os serviços chegarem.
5. **⚠️ No Arch, NUNCA dar checkout desta branch em `~/dotfiles`** — os symlinks do stow
   apontam pro worktree; os configs do sistema vivo sumiriam do disco. Pra mexer nela a
   partir do Arch: `git worktree add ~/nixos-wt nixos`. No NixOS, ela é a branch natural.

## Arquitetura alvo (construir gradualmente)

```text
├── flake.nix                       # maestro: unifica sistema (root) + home (usuário)
├── flake.lock                      # cápsula do tempo dos pins
├── configuration.nix               # << ponto de partida (fase 0, pré-flake)
├── hosts/
│   ├── trialboot/                  # laboratório (disco secundário)
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix   # gerado pela ISO (nixos-generate-config)
│   └── workstation/                # destino final (Kingston, pós-cutover)
├── home/                           # home-manager modular (git.nix, shell.nix, ...)
└── pkgs/                           # derivations próprias ("AUR pessoal")
```

## Fases

**0. Instalação (disco secundário, trialboot)** — *bloqueada: disco ainda fora do gabinete*
- ISO minimal: <https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso>
- Particionar por `/dev/disk/by-id/` (nomes `sdX`/`nvmeX` embaralham nesta máquina!);
  **ESP própria no disco secundário — jamais a do Kingston**; rEFInd detecta sozinho.
- Kit anti-cegueira no 1º `configuration.nix` (ver comentários no arquivo): NetworkManager,
  **openssh** (permite configurar via SSH sentado no Arch), usuário, git, editor.

**1. Base** — migrar pra flake + `hosts/trialboot/` + home-manager no mesmo repo.
**2. Desktop** — hyprland, greetd, pipewire, bluetooth, fontes.
**3. Rice** — trazer os configs da main: `git checkout main -- hypr/ quickshell/ kitty/ ...`
   (hot-edit: `mkOutOfStoreSymlink` nos dirs de iteração rápida).
**4. Homelab** — caddy, fail2ban, wireguard, docker/oci-containers, DDNS.
**5. Chefões** — NetExtender via `buildFHSEnv`, sops-nix, derivations próprias, distrobox
   Arch (`--nvidia`) como playground pacman/AUR.
**6. Cutover** — quando o trialboot aguentar 1 semana de rotina real (trabalho+estudo),
   aplicar o flake no Kingston (`hosts/workstation/`). Arch aposentado.

## Atritos conhecidos → antídotos

| Atrito | Antídoto |
|---|---|
| Wheels Python/CUDA assumem FHS (`uv pip install torch`) | `programs.nix-ld.enable = true` no dia 1 |
| Containers com GPU (open-webui etc.) | `hardware.nvidia-container-toolkit.enable = true` |
| home-manager = symlink read-only (mata hot-reload QML) | `mkOutOfStoreSymlink` nos dirs quentes |
| NetExtender (FHS + daemon NEService, sem pacote) | `buildFHSEnv`; reservar um fim de semana |
| ~5 pacotes AUR sem equivalente | derivation própria / `appimageTools` / `nix-init` |
| Saudade do pacman | `nix shell nixpkgs#pkg`, `nix search`, `comma`; distrobox |

## Discos (contexto 2026-07-13)

- **Kingston (nvme)** = Arch, produção. Não tocar até o cutover.
- **Netac NE-1TB** = MORTO (controlador cai do barramento; resgate concluído, perda zero).
- **sdb SanDisk 1TB** = tem Windows antigo; conferir/limpar antes de usar como trialboot.

## Diário

- **2026-07-13** — Branch criada e zerada (só `configuration.nix` + este README). Esqueleto
  flake testado em VM preservado na tag `nix-flake-skeleton`. Decisões: unstable no host,
  reescrita à mão pra aprender, trialboot em disco secundário (aguardando hardware).
- **2026-07-15** — Realidade adiantou o plano: NixOS 26.05 instalado direto no **HDD Seagate**
  (host `nixos-seagate`, GNOME, SSH:2222), sem esperar o trialboot. Arquitetura de flake
  montada e unificada **sistema + usuário** via **home-manager como módulo do NixOS** (um só
  rebuild aplica os dois, atômico). Layout escolhido: **duas pastas** que espelham o modelo
  mental — `system/` (root) e `home/` (usuário) — em vez de `hosts/`+`modules/` (indireção
  que só se paga com VÁRIAS máquinas; hoje há uma). `hardware-configuration.nix` na raiz.
  Apps de usuário (chrome, vscode, librewolf, claude-code) migrados de `systemPackages` →
  `home.packages`. Teclado ABNT2 corrigido (GNOME/Wayland ignora o xkb do sistema na sessão
  → declarado em `home/gnome.nix`). `configuration.nix` da raiz (fase 0) aposentado.
  Rebuild: `sudo nixos-rebuild switch --flake .#nixos-seagate`.

  ```text
  flake.nix                    # cola sistema + usuário
  hardware-configuration.nix   # gerado, não editar
  system/default.nix           # SISTEMA (cresce: system/audio.nix, fonts.nix…)
  home/{default,apps,git,gnome}.nix   # USUÁRIO (cresce: home/kitty.nix, hypr.nix…)
  ```

  Migração dos configs de app (fase Rice): **híbrido** — módulos nativos do home-manager
  onde existem (`programs.kitty/zsh/git/starship`), e arquivo cru via `mkOutOfStoreSymlink`
  pro rice que precisa de hot-reload (Hyprland/Quickshell).
