# Anotações

> Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)

- [ ] Instalar o flameshot — DEPOIS no SSD (precisa compilar c/ enableWlrSupport;
      lento no HDD). Alternativa nativa sem compilar: grim + slurp + swappy.
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [ ] Adicionar um software para notificações
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/theme.nix)
  - [ ] Adicionar o tema Windows 11 no file manager

Ambos com systemd (ou algo semelhante) e rodando em daemon (background):

- [ ] Adicionar o servidor de Midia (Jellyfin) com linguagem Nix
- [ ] Adicionar o duolingo rodando para fazer automaticamente com Nix
