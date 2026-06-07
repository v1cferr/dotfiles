# scripts/packages/

Listas de pacotes instalados, mantidas **automaticamente atualizadas** por um
timer de usuário (a cada 5min). Servem para reprodução em outra máquina e para
revisar pacotes inúteis (tanto do pacman quanto do AUR).

Fica em `scripts/` (e não no topo do repo) de propósito: o `stow-sync` ignora
`scripts/`, então estes arquivos de dados nunca são stowados para o `$HOME`.

## Arquivos gerados

| Arquivo | Conteúdo | Comando-fonte |
|---------|----------|---------------|
| `pacman-explicit.txt` | Explícitos dos repos oficiais (nome + versão) | `pacman -Qen` |
| `aur.txt` | Explícitos foreign/AUR (nome + versão) | `pacman -Qem` |
| `orphans.txt` | Deps órfãs (candidatas a remoção; pode ser vazio) | `pacman -Qdtq` |

As listas têm **versão** (pra registrar o histórico de updates no git) e são
ordenadas pra o diff ficar limpo.

## Como funciona

- `sync.sh` regenera os 3 arquivos. **Não faz git** — só atualiza os `.txt`.
- `dotfiles-pkgsync.service` + `.timer` (units de **usuário**) rodam o `sync.sh`
  a cada 5min (e uma vez ~2min após o boot).
- Como o yay usa o pacman por baixo, instalar/remover via pacman **ou** AUR é
  capturado nas próximas execuções.

O versionamento é **manual**: revise o diff e commite quando quiser.

```bash
git -C ~/dotfiles add scripts/packages/*.txt
git -C ~/dotfiles commit -m "chore(packages): atualiza listas"
```

## Instalar / ativar o timer

```bash
~/dotfiles/scripts/packages/install.sh    # sem sudo (timer de usuário)
```

Conferir:

```bash
systemctl --user list-timers dotfiles-pkgsync.timer
systemctl --user status dotfiles-pkgsync.service
```

## Reinstalar os pacotes em outra máquina

As listas têm versão; para reinstalar use só os nomes:

```bash
# Oficiais
sudo pacman -S --needed - < <(awk '{print $1}' pacman-explicit.txt)

# AUR (com yay)
yay -S --needed - < <(awk '{print $1}' aur.txt)
```

## Limpar órfãos

```bash
pacman -Qtdq | sudo pacman -Rns -    # remove o que está em orphans.txt
```
