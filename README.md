# Migração pro SSD SanDisk — passo a passo

Siga na ordem, **bootado no live USB do NixOS** (ISO minimal 26.05).

> ⚠️ O **Passo 3 APAGA a SanDisk** (o Windows dela). Arch (Kingston) e HDD (Seagate) ficam
> intactos. Tenha em mãos a **senha-mestra do Bitwarden** (é dela que sai a chave age).

## Passo 1 — Rede

Cabo ethernet já pega DHCP (o cutover precisa de internet). Confirme:

```bash
ping -c1 github.com
```

## Passo 2 — Trazer o repo

```bash
nix-shell -p git
git clone https://github.com/v1cferr/dotfiles ~/dotfiles
cd ~/dotfiles && git checkout nixos
```

## Passo 3 — Instalar (formata a SanDisk + instala o NixOS)

```bash
sudo ./scripts/cutover-sandisk.sh
```

Ele pede pra digitar `FORMATAR` (confirmação), formata a SanDisk, restaura a chave age do
Bitwarden (só a senha-mestra) e roda o `nixos-install`.

## Passo 4 — Reiniciar

```bash
reboot
```

Tire o pendrive e boote na SanDisk (ajuste a ordem de boot na BIOS, se preciso).

## Passo 5 — Restaurar seus dados (já na SanDisk)

Logue com sua senha de sempre. Abra um **TTY** (Ctrl+Alt+F3) pra não mexer no `~` em uso, e:

```bash
git clone https://github.com/v1cferr/dotfiles ~/dotfiles && cd ~/dotfiles
sudo ./scripts/restore-home.sh
```

Monta o HDD Seagate e restaura seu `~` (Zen, `.claude`, VSCode, documentos) do backup restic.

## Passo 6 — Re-parear o fone

```bash
bluetoothctl
# scan on  →  pair <MAC>  →  trust <MAC>  →  connect <MAC>  →  exit
```

Pronto — sistema migrado pro SanDisk. 🎮

---

> Documentação completa do repo (layout, regras, sops/restic, roadmap, diário) está no
> histórico do git — dá pra restaurar depois: `git show HEAD~1:README.md`.
