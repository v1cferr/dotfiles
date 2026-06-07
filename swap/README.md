# swap/

Esquema de **swap em camadas** desta máquina (16GB de RAM, uso pesado com muita
coisa aberta + daemons). Configuração de `/etc`, então **não é coberta pelo stow**
— é aplicada pelo `scripts/swap/deploy.sh`.

## Camadas

| Camada | Tamanho | Prioridade | Papel |
|--------|---------|------------|-------|
| `zram0` (RAM comprimida, zstd) | `ram` (~16G) | 100 | Tier rápido, usado primeiro |
| `/swapfile` (disco, NVMe) | 16G | 10 | Overflow / rede de segurança contra OOM |

O kernel sempre enche o swap de **maior** prioridade primeiro, então o `/swapfile`
só é tocado quando o zram lota. Total: ~32G de swap.

Sem hibernação (a máquina faz dual-boot e o suspend-to-RAM basta no Linux), por
isso o swap em disco não precisa ser ≥ RAM nem configurar `resume=`.

## Arquivos versionados

- `swap/etc/systemd/zram-generator.conf` — config do `zram-generator` (espelha `/etc/systemd/`).

O `/swapfile` (16G binário) **não** é versionado: o deploy o cria. E o `/etc/fstab`
**não** é sobrescrito (tem UUIDs machine-specific) — o deploy só garante, de forma
idempotente, a linha do swapfile.

## Deploy

```bash
# Pré-requisito (uma vez):
sudo pacman -S zram-generator

# Aplicar (idempotente):
sudo ~/dotfiles/scripts/swap/deploy.sh
```

## Conferir

```bash
swapon --show   # zram0 (prio 100) + /swapfile (prio 10)
free -h
```

## Ajustar

- Tamanho/algoritmo do zram: edite `etc/systemd/zram-generator.conf` (ex.: `zram-size = ram * 2`).
- Tamanho/prioridade do swapfile: variáveis no topo de `scripts/swap/deploy.sh`.
