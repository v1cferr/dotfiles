# dotfiles — NixOS declarativo

Sistema inteiro **declarativo e versionado**: reconstruível em qualquer máquina com um
comando. Host atual: **`nixos-seagate`** (HDD Seagate, XFCE). Branch de trabalho: **`nixos`**.

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
flake.nix                    # maestro: cola sistema (root) + usuário (home-manager)
flake.lock                   # pins (cápsula do tempo)
hardware-configuration.nix   # gerado pela máquina — não editar
system/default.nix           # SISTEMA: pacotes, serviços, boot, rede, desktop…
home/                        # USUÁRIO: só CONFIGURA (não instala) — git.nix, …
secrets/secrets.yaml         # segredos criptografados (sops-nix)
.sops.yaml                   # regras de encriptação (recipient age)
pkgs/                        # derivations próprias ("AUR pessoal")
```

**Sistema + usuário num só rebuild:** o home-manager entra como módulo do NixOS, então
`nixos-rebuild switch` aplica os dois de forma atômica. Regra de ouro do repo:
**pacote = `system/`, configuração = `home/`.**

---

## Regras do jogo

1. **Capacidade se declara, estado não.** Bluetooth ligado = config; fone pareado = estado.
   Idem senhas de Wi-Fi, volumes Docker, perfil de navegador.
2. **Flakes só enxergam arquivos rastreados** → `git add` antes de QUALQUER rebuild.
3. **Nada imperativo.** Sem `nix-env`/`nix profile add`. Tudo no config + rebuild.
4. **Segredo nunca em claro no git** (iria legível pra `/nix/store`) → sops-nix.
5. **Canal `nixos-unstable`** no flake (bleeding edge, estilo Arch).
6. **⚠️ No Arch, NUNCA dar checkout da branch `nixos` em `~/dotfiles`** — os symlinks do stow
   apontam pro worktree e os configs do Arch vivo sumiriam. Use `git worktree add ~/nixos-wt nixos`.

---

## Segredos (sops-nix)

Segredos criptografados versionados em `secrets/secrets.yaml`; a chave **privada** age vive
em `/var/lib/sops-nix/key.txt` (FORA do git — é o que se leva no cutover).

```bash
# editar/adicionar segredos (encripta sozinho pro recipient do .sops.yaml):
nix shell nixpkgs#sops -c sops secrets/secrets.yaml
git add secrets/secrets.yaml && sudo nixos-rebuild switch --flake .#nixos-seagate
```

Consumidos hoje: senha do usuário (`hashedPasswordFile`) e token do Cloudflare DDNS.

---

## Roadmap

- [x] Flake unificado sistema + home-manager
- [x] sops-nix (senha + DDNS)
- [x] DE leve interino: **XFCE + LightDM** (GNOME pesava no HDD)
- [ ] **Rice Hyprland + Quickshell** — trazer configs da `main`
      (`git checkout main -- hypr/ quickshell/ …`; `mkOutOfStoreSymlink` nos dirs de hot-reload)
- [ ] Homelab: caddy, wireguard, docker/oci-containers
- [ ] NetExtender via `buildFHSEnv`; distrobox Arch (`--nvidia`) como playground pacman/AUR
- [ ] **Cutover**: aplicar o flake no Kingston quando a rotina real aguentar 1 semana

### Atritos conhecidos → antídotos

| Atrito | Antídoto |
|---|---|
| Wheels Python/CUDA assumem FHS (`uv pip install torch`) | `programs.nix-ld.enable = true` (já ligado) |
| Containers com GPU (open-webui etc.) | `hardware.nvidia-container-toolkit.enable = true` |
| home-manager = symlink read-only (mata hot-reload QML) | `mkOutOfStoreSymlink` nos dirs quentes |
| NetExtender (FHS + daemon, sem pacote) | `buildFHSEnv`; reservar um fim de semana |
| Saudade do pacman | `nix shell nixpkgs#pkg`, `nix search`, `comma`, distrobox |

---

## Diário

- **2026-07-13** — Branch `nixos` criada e zerada. Esqueleto flake testado em VM na tag
  `nix-flake-skeleton`. Decisões: unstable no host, reescrita à mão pra aprender.
- **2026-07-15** — NixOS 26.05 instalado direto no **HDD Seagate** (host `nixos-seagate`).
  Flake unificado **sistema + usuário** via home-manager como módulo. Layout: `system/` (root)
  + `home/` (usuário), em vez de `hosts/`+`modules/` (indireção só paga com várias máquinas).
- **2026-07-16** — Migração consolidada: **sops-nix** (senha + Cloudflare DDNS), **gh** como
  credential helper do git (push HTTPS por token), troca **GNOME/GDM → XFCE/LightDM** (HDD lento),
  LG ULTRAGEAR como monitor primário, GC reativo por espaço (`min-free`/`max-free`).
  Histórico pré-Nix colapsado na tag `archive/pre-nix-2026-07-16`.
