# homelab/

**Backup versionado das configs dos stacks Docker** que rodam nesta máquina.
Objetivo: se o PC falhar, dá pra reconstruir o homelab a partir do GitHub.

> Aqui ficam só as **configs** (compose + arquivos de dashboard). Os stacks
> continuam rodando de `~/Projects/Local/` (com seus dados). Isto é uma cópia
> de backup, não o runtime — segredos e dados pesados ficam no `.gitignore`.

## Stacks

| Stack | O que roda | Exposto via |
|-------|------------|-------------|
| `jellyfin/` | Jellyfin, Jellyseerr, Prowlarr, Radarr, Sonarr, Bazarr, qBittorrent, FlareSolverr, cloudflared | Caddy (`*.v1cferr.dev`) |
| `homepage/` | Homepage (dashboard) + docker-socket-proxy | Caddy `dash.v1cferr.dev` (LAN) |
| `filebrowser/` | FileBrowser | Caddy `files.v1cferr.dev` |
| `rustdesk/` | RustDesk server (hbbs + hbbr) — relay self-hosted | host network · **parado no momento** |

> O stack **spendflow** não está aqui: ele já é versionado no próprio repo
> (`~/Projects/GitHub/v1cferr/spendflow`). O reverse-proxy é o **Caddy do
> sistema** (versionado em `../caddy/`), não um container.

## O que NÃO entra no git (tudo no `.gitignore` central do root)

- `jellyfin/.env` — `TUNNEL_TOKEN` + API keys (vive em `~/Projects/Local/jellyfin/.env`). Modelo: seção "Stacks Docker" do `~/dotfiles/.env.example`.
- `jellyfin/config/` — ~700M de estado dos serviços (regenerável).
- `filebrowser/database/` — banco de usuários/senhas.
- `homepage/config/logs/` — logs runtime.
- `rustdesk/data/` — chave do relay (`id_ed25519`) + estado runtime.
- Mídia (`/home/v1cferr/Videos/Jellyfin`) e pastas montadas no FileBrowser —
  ficam fora do repo por natureza (bind mounts absolutos).

## Reconstruir um stack

```bash
# Ex.: stack de mídia
mkdir -p ~/homelab && cp -r ~/dotfiles/homelab/jellyfin ~/homelab/
cd ~/homelab/jellyfin
# crie o .env a partir da seção "Stacks Docker" do ~/dotfiles/.env.example
$EDITOR .env                              # preencha tokens/API keys
docker compose up -d
```

Os serviços recriam o `./config/<app>` vazio e inicializam do zero; restaure
backups de config se tiver. A mídia é apontada pelo caminho absoluto do compose.

## Manter atualizado

Estas configs são **cópias**. Se editar um compose/config no runtime
(`~/Projects/Local/...`), copie de volta pra cá e commite. Os tokens nunca
saem do `.env` local.
