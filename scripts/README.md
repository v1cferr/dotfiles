# scripts/

Scripts de administração, executados pelo caminho explícito (não vão para o PATH). Os comandos de uso diário ficam em `bin/` (ver `bin/README.md`).

Este diretório NÃO é aplicado com stow: o `stow-all` o ignora de propósito (ele contém scripts chamados por caminho, não dotfiles que devem ir para o `$HOME`).

## Conteúdo

- `stow-sync.sh` — gerencia os dotfiles com GNU Stow: `list`, `status`, `stow`, `unstow`, `stow-all`, `restow-all`, `info`. Ver `../README.stow.md`.
- `caddy/deploy.sh` — copia o `Caddyfile` e o drop-in do systemd para `/etc` e recarrega o Caddy (o stow não cobre `/etc`). Requer root.
- `fail2ban/deploy.sh` — copia as jails e filtros do fail2ban para `/etc` e reinicia o serviço. Requer root.
- `swap/deploy.sh` — aplica o swap em camadas: copia o `zram-generator.conf` para `/etc/systemd/`, cria o `/swapfile` (16G) se faltar, garante a entrada no `/etc/fstab` e reativa o swap. Idempotente. Requer root.
- `cloudflare-ddns/deploy.sh` — instala as units systemd do DDNS do Cloudflare em `/etc`, resolvendo o caminho do projeto. Requer root e o `.env` centralizado no root (gitignored).
- `ssh/deploy.sh` — instala o drop-in do SSH (porta 2222 + hardening); valida com `sshd -t` e faz reload (sem lockout). Requer root.
- `docker/deploy.sh` — instala o `daemon.json` do Docker e recarrega (sem restart, pra não derrubar os containers). Requer root.
- `system/deploy.sh` — instala `pacman.conf` + hook + `makepkg.conf`(.d). `mkinitcpio.conf` e `boot/` são só referência. Requer root.
- `netextender/deploy.sh` — instala o perfil de VPN SonicWall em `/etc/SonicWall/` (não é stow, tem estrutura de `/etc`). Requer root.
- `secrets/` — backup CRIPTOGRAFADO dos segredos (SSH/GPG/`.env`/tokens) num arquivo único `secrets-backup.tar.gz.gpg` na raiz (gitignored). `backup.sh` gera; `install.sh` ativa o timer diário (precisa de `~/.config/secrets-backup.passphrase`). Base do DR — ver `../RESTORE.md`.
- `packages/` — automação que regenera as listas de pacotes (pacman + AUR) a cada 5min via timer de usuário. `install.sh` ativa (sem sudo); `sync.sh` é o worker. Ver `../scripts/packages/README.md`.
- `fai-ufscar-vpn.sh` — conecta na VPN SonicWall da FAI.UFSCAR via netExtender. Usado pelo comando `vpn` e pelo alias `vpn-fai`.
- `ufscar-vpn.sh` — conexão da VPN da UFSCar (alias `vpn-ufscar`).

## Uso

```bash
# Dotfiles
./stow-sync.sh list
./stow-sync.sh stow-all

# Deploy de configs de sistema (/etc) — requer root
sudo ~/dotfiles/scripts/caddy/deploy.sh
sudo ~/dotfiles/scripts/fail2ban/deploy.sh
sudo ~/dotfiles/scripts/swap/deploy.sh
sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
sudo ~/dotfiles/scripts/ssh/deploy.sh
sudo ~/dotfiles/scripts/docker/deploy.sh
sudo ~/dotfiles/scripts/system/deploy.sh
sudo ~/dotfiles/scripts/netextender/deploy.sh

# Automação de pacotes (timer de usuário, SEM sudo)
~/dotfiles/scripts/packages/install.sh
```
