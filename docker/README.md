# docker/

Config do **daemon do Docker** (`/etc/docker/daemon.json`) — registra o runtime
`nvidia` (GPU nos containers). Config de `/etc`, aplicada por
`scripts/docker/deploy.sh`.

## Deploy

```bash
sudo ~/dotfiles/scripts/docker/deploy.sh
```

O deploy valida o JSON e faz `reload` (SIGHUP). **Não reinicia o Docker** (isso
derrubaria todos os containers do homelab); mudanças de runtime/storage exigem
`sudo systemctl restart docker` manual, quando der.

> Os stacks Docker (compose) ficam em `../homelab/`. Aqui é só o daemon.
