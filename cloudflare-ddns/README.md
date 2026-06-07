# cloudflare-ddns/

Atualizador de **DNS dinâmico** do Cloudflare: mantém um registro A apontando
para o IP público atual (usado para o acesso SSH externo, `ssh.v1cferr.dev`).
Roda como serviço de sistema (systemd timer). Config de `/etc`, então **não é
coberto pelo stow** — é aplicado pelo `scripts/cloudflare-ddns/deploy.sh`.

> Versionado a partir do projeto original em `~/Projects/Local/cloudflare`
> (já removido). Os antigos `install.sh`/`setup.sh` foram substituídos pelo
> `deploy.sh` no padrão dos outros configs de `/etc` (caddy, fail2ban).

## Estrutura

```text
cloudflare-ddns/
├── bin/cloudflare-ddns.sh                       # worker (curl + API Cloudflare)
└── etc/systemd/system/
    ├── cloudflare-ddns.service                  # unit (placeholder __DDNS_DIR__)
    └── cloudflare-ddns.timer                    # roda a cada 2min
```

## Segredos (centralizados no `.env` do root)

As variáveis do DDNS (`API_TOKEN`, `ZONE_ID`, `RECORD_ID`, `RECORD_NAME`) ficam
no **`.env` centralizado no root dos dotfiles** (`~/dotfiles/.env`, gitignored),
junto com as do Caddy. O modelo é o `~/dotfiles/.env.example`. O worker lê esse
`.env` via caminho relativo (`${PROJECT_DIR}/../.env`). O `API_TOKEN` do DDNS é
um token **próprio**, diferente do `CLOUDFLARE_API_TOKEN` do Caddy.

## Deploy

```bash
# 1) Garanta que ~/dotfiles/.env existe e tem as variáveis do DDNS:
cp ~/dotfiles/.env.example ~/dotfiles/.env   # se ainda não existir
$EDITOR ~/dotfiles/.env                        # preencha API_TOKEN/ZONE_ID/RECORD_ID/RECORD_NAME

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

- O worker se auto-localiza: lê o `.env` do root e grava `logs/ddns.log` +
  `.current_ip` relativos ao próprio diretório (gitignored via root `.gitignore`).
  Rodando via systemd como root, esses logs ficam dentro de `cloudflare-ddns/`.
