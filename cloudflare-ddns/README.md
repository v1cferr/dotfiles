# cloudflare-ddns/

Atualizador de **DNS dinâmico** do Cloudflare: mantém um registro A apontando
para o IP público atual (usado para o acesso SSH externo, `ssh.v1cferr.dev`).
Roda como serviço de sistema (systemd timer). Config de `/etc`, então **não é
coberto pelo stow** — é aplicado pelo `scripts/cloudflare-ddns/deploy.sh`.

> Versionado a partir do projeto original em `~/Projects/Local/cloudflare`.
> Os antigos `install.sh`/`setup.sh`/`QUICKSTART.sh` foram substituídos pelo
> `deploy.sh` no padrão dos outros configs de `/etc` (caddy, fail2ban).

## Estrutura

```text
cloudflare-ddns/
├── bin/cloudflare-ddns.sh                       # worker (curl + API Cloudflare)
├── config/.env.example                          # modelo (SEM token)
├── etc/systemd/system/cloudflare-ddns.service   # unit (placeholder __DDNS_DIR__)
├── etc/systemd/system/cloudflare-ddns.timer     # roda a cada 2min
└── .gitignore                                   # ignora config/.env, logs/
```

## Segredos

`config/.env` (com `API_TOKEN`, `ZONE_ID`, `RECORD_ID`, `RECORD_NAME`) é
**gitignored** — nunca é versionado. Só o `.env.example` (com placeholders)
entra no repo.

## Deploy

```bash
# 1) Crie o .env com seu token (uma vez):
cp ~/dotfiles/cloudflare-ddns/config/.env.example ~/dotfiles/cloudflare-ddns/config/.env
$EDITOR ~/dotfiles/cloudflare-ddns/config/.env

# 2) Instale as units (resolve o caminho, ativa o timer):
sudo ~/dotfiles/scripts/cloudflare-ddns/deploy.sh
```

O `deploy.sh` substitui o placeholder `__DDNS_DIR__` pelo caminho real do
projeto nos dotfiles ao copiar as units para `/etc/systemd/system/`.

## Conferir

```bash
systemctl status cloudflare-ddns.timer
journalctl -u cloudflare-ddns.service -n 20
```

## Notas

- O worker se auto-localiza: lê `config/.env` e grava `logs/ddns.log` +
  `.current_ip` relativos ao próprio diretório. Rodando via systemd como root,
  esses arquivos de log ficam dentro de `cloudflare-ddns/` (gitignored).
- O runtime atual ainda roda a partir de `~/Projects/Local/cloudflare`. Para
  migrar para esta cópia versionada, faça o deploy acima — ele reescreve as
  units de `/etc` para apontarem aqui. (Opcional; nada quebra se não migrar.)
