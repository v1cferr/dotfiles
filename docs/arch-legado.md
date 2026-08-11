# Legado do Arch Linux

Capítulo ENCERRADO. Fica aqui porque o acervo ainda existe e repo que ninguém
sabe abrir é pior que repo apagado.

> Aqui estão minhas configurações legado do Arch Linux que estamos migrando tudo para o Nix e NixOS, para que tudo seja declarativo e não manual, e para que funcione em qualquer hardware posteriormente.

Encerrado em 05/08/2026. O Kingston foi formatado (01/08), o módulo que criava os backups
foi apagado, a cópia manual `~/BACKUP-KINGSTON` foi apagada e a perna local (Seagate) saiu
— ficou **só a cópia offsite**, que passou no `check --read-data` (189 packs, 0 erros).

Sobra este ponteiro porque repo que ninguém sabe abrir é pior que repo apagado:

A pasta no Drive foi renomeada `KINGSTON` → **`ARCH-KINGSTON`** em 05/08/2026 (o nome
antigo não dizia que era o Arch).

**Não há comando pra rodar**: desde 11/08/2026 o acervo fica montado em
`/mnt/arch-antigo` desde o login — é só abrir o bookmark **Arch antigo** no Dolphin. Quem
monta é a unit de usuário `arch-antigo-mount`
([`home/services/arch-antigo-mount.nix`](../home/services/arch-antigo-mount.nix)); o
mountpoint e a SSOT do caminho são do lado sistema
([`system/services/arch-antigo.nix`](../system/services/arch-antigo.nix)). O alias
`arch-browse` morreu junto — pasta vazia aqui virou sintoma, não estado normal:

```bash
systemctl --user status arch-antigo-mount   # pasta vazia? o diagnóstico começa aqui
systemctl --user restart arch-antigo-mount  # mount zumbi depois de queda de rede
```

⚠️ Desligue a **visualização** (miniaturas) no Dolphin antes de navegar aqui: preview lê o
CONTEÚDO, e cada leitura faz o restic baixar packs do Drive. Medido: uma pasta de 3,9 MiB
custou 3,68 MiB de download só em ícone (ver TODO de 07/08/2026). Com o mount permanente
isso ficou mais importante, não menos — a pasta está sempre a um clique.

O mount roda como USUÁRIO de propósito: mount FUSE é privado de quem montou, então
`sudo restic mount` gera pasta que o file manager não abre. Os dotfiles do Arch estão em
`home/v1cferr/dotfiles` dentro do snapshot (`6d7e3ee7`, 44,6 GiB). Os dois segredos seguem
declarados de propósito — são a CHAVE do acervo, não sobra do módulo.

- Repo no GitHub: <https://github.com/v1cferr/dotfiles>
