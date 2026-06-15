# RESTORE — Reconstruir esta workstation do zero

Runbook de disaster recovery para o Arch Linux + Hyprland do v1cferr. Use se o
NVMe morrer ou ao montar uma máquina nova. A ordem importa.

> **Pré-requisitos:** mídia de boot do Arch, internet, acesso ao GitHub
> (`v1cferr/dotfiles`) e — crucial — o **backup criptografado dos segredos**
> (`secrets-backup-*.tar.gz.gpg`, gerado por `scripts/backup-secrets.sh`) + a
> sua **passphrase**. Sem os segredos, SSH/GPG/tokens não voltam.

---

## 1. Base do Arch (a partir do ISO)

Instale a base seguindo o [Guia de Instalação](https://wiki.archlinux.org/title/Installation_guide).
Resumo do que esta máquina usa (ver `system/` para referência):

- Partição EFI (`/boot`, vfat) + raiz **ext4** no NVMe.
- `pacstrap -K /mnt base linux linux-firmware base-devel git`
- Bootloader: **systemd-boot** (`bootctl install`). As entradas em
  `system/boot/loader/` são referência — **ajuste o `root=UUID`** para o UUID
  real da nova raiz (`blkid`).
- `system/etc/mkinitcpio.conf` é referência — compare os HOOKS e rode
  `mkinitcpio -P`.
- Locale/teclado: `system/etc/{locale.conf,vconsole.conf}` como base.

Crie o usuário `v1cferr`, dê sudo, e faça login nele para o resto.

## 2. Ferramentas essenciais (primeiro boot)

```bash
sudo pacman -S --needed git stow base-devel
# AUR helper (yay):
git clone https://aur.archlinux.org/yay-bin.git /tmp/yay && (cd /tmp/yay && makepkg -si)
```

## 3. Clonar os dotfiles

```bash
git clone https://github.com/v1cferr/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

## 4. Restaurar os pacotes

As listas são mantidas em `scripts/packages/` (têm nome+versão; aqui usamos só os nomes):

```bash
# Repos oficiais
awk '{print $1}' scripts/packages/pacman-explicit.txt | sudo pacman -S --needed -
# AUR (com yay)
awk '{print $1}' scripts/packages/aur.txt | yay -S --needed -
```

## 5. Aplicar os dotfiles (stow)

Use a lista explícita (NÃO `stow-all` — ele tentaria stowar os pacotes de `/etc`
e criaria um `~/etc` errado):

```bash
cd ~/dotfiles
stow hypr rofi waybar zsh vscode gtk-3.0 gtk-4.0 flameshot wallpapers git bin \
     kitty starship swaync networkmanager cloudflare fastfetch opencode \
     zen-browser nvim mpv btop fontconfig spicetify easyeffects atuin autostart \
     xsettingsd gh lazydocker uv openrazer polychromatic pacseek vlc bash nano
# Zen browser: linka no profile via script próprio
zen-sync   # (ou ~/dotfiles/zen-browser/... conforme o README do pacote)
```

## 6. Restaurar os SEGREDOS (antes dos deploys de /etc)

```bash
# Traga o secrets-backup.tar.gz.gpg do seu Dropbox/HDD e:
gpg -d secrets-backup.tar.gz.gpg | tar -xzf - -C ~
# Isto restaura ~/.ssh, ~/.gnupg, ~/dotfiles/.env, tokens, etc.
chmod 700 ~/.ssh ~/.gnupg
```

## 7. Deploy dos configs de sistema (`/etc`) — requer root

```bash
sudo ~/dotfiles/scripts/system/deploy.sh         # pacman.conf, makepkg, locale...
sudo ~/dotfiles/scripts/ssh/deploy.sh            # sshd (porta 2222)
sudo ~/dotfiles/scripts/docker/deploy.sh         # daemon.json (precisa do docker)
sudo ~/dotfiles/scripts/caddy/deploy.sh          # reverse proxy (usa ~/dotfiles/.env)
sudo ~/dotfiles/scripts/fail2ban/deploy.sh
sudo ~/dotfiles/scripts/swap/deploy.sh           # zram + swapfile (pacman -S zram-generator antes)
sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
sudo ~/dotfiles/scripts/netextender/deploy.sh    # perfil VPN (se usar)

# Display manager: greetd + greeter quickshell (substitui o SDDM)
sudo pacman -S greetd
sudo ~/dotfiles/scripts/greetd/deploy.sh         # configs + coletor de status
sudo ~/dotfiles/scripts/greetd/switch-to-greetd.sh   # habilita greetd como DM
```

## 8. Automação + serviços

```bash
~/dotfiles/scripts/packages/install.sh    # timer de usuário que mantém as listas de pacote
# Habilite os serviços que usa, ex.:
sudo systemctl enable --now sshd docker fail2ban caddy
```

## 9. Homelab (opcional)

Os stacks Docker rodam de fora do repo. As **configs** estão em `homelab/`
(ver `homelab/README.md`): copie pra `~/Projects/Local/<stack>/`, crie o `.env`
de cada um (modelo na seção "Stacks Docker" do `.env.example`) e
`docker compose up -d`. Os **dados** (mídia, bancos) vêm do seu backup à parte.

## 10. Checklist final

- [ ] greetd sobe o greeter quickshell no boot; senha loga na sessão uwsm
      (`readlink /etc/systemd/system/display-manager.service` → greetd; se quebrar,
      via SSH/console: `sudo systemctl disable greetd` — há o `agreety` de emergência)
- [ ] Hyprland sobe e os atalhos funcionam (ver `README.hyprland.md`)
- [ ] `stow-sync.sh status` sem links quebrados
- [ ] SSH/GPG funcionando (`ssh -T git@github.com`, `gpg -K`)
- [ ] Caddy servindo `*.v1cferr.dev`; DDNS atualizando
- [ ] Reative o backup de segredos: `~/dotfiles/scripts/secrets/install.sh`

---

**Manter este runbook vivo:** sempre que adicionar um pacote de `/etc` novo ou
um serviço, atualize os passos 5 e 7. O que não está aqui não volta fácil.
