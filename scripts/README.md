# scripts/

Scripts de administração, executados pelo caminho explícito (não vão para o PATH). Os comandos de uso diário ficam em `bin/` (ver `bin/README.md`).

Este diretório NÃO é aplicado com stow: o `stow-all` o ignora de propósito (ele contém scripts chamados por caminho, não dotfiles que devem ir para o `$HOME`).

## Conteúdo

- `stow-sync.sh` — gerencia os dotfiles com GNU Stow: `list`, `status`, `stow`, `unstow`, `stow-all`, `restow-all`, `info`. Ver `../README.stow.md`.
- `caddy/deploy.sh` — copia o `Caddyfile` e o drop-in do systemd para `/etc` e recarrega o Caddy (o stow não cobre `/etc`). Requer root.
- `fail2ban/deploy.sh` — copia as jails e filtros do fail2ban para `/etc` e reinicia o serviço. Requer root.
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
```
