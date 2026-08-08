# Legado do Arch Linux

Capítulo ENCERRADO. Fica aqui porque o acervo ainda existe e repo que ninguém
sabe abrir é pior que repo apagado.

> Aqui estão minhas configurações legado do Arch Linux que estamos migrando tudo para o Nix e NixOS, para que tudo seja declarativo e não manual, e para que funcione em qualquer hardware posteriormente.

Encerrado em 05/08/2026. O Kingston foi formatado (01/08), o módulo que criava os backups
foi apagado, a cópia manual `~/BACKUP-KINGSTON` foi apagada e a perna local (Seagate) saiu
— ficou **só a cópia offsite**, que passou no `check --read-data` (189 packs, 0 erros).

Sobra este ponteiro porque repo que ninguém sabe abrir é pior que repo apagado:

A pasta no Drive foi renomeada `KINGSTON` → **`ARCH-KINGSTON`** em 05/08/2026 (o nome
antigo não dizia que era o Arch). Navegar como pasta, no Dolphin:

```bash
arch-browse                     # monta em /mnt/arch-antigo (Ctrl+C desmonta)
```

⚠️ Desligue a **visualização** (miniaturas) no Dolphin antes de navegar aqui: preview lê o
CONTEÚDO, e cada leitura faz o restic baixar packs do Drive. Medido: uma pasta de 3,9 MiB
custou 3,68 MiB de download só em ícone (ver TODO de 07/08/2026).

O alias está em `home/shell/zsh.nix` e roda SEM sudo de propósito: mount FUSE é privado
de quem montou, então `sudo restic mount` gera pasta que o file manager não abre. Os
dotfiles do Arch estão em `home/v1cferr/dotfiles` dentro do snapshot (`6d7e3ee7`, 44,6
GiB). Os dois segredos seguem declarados de propósito — são a CHAVE do acervo, não sobra
do módulo.

- Repo no GitHub: <https://github.com/v1cferr/dotfiles>
