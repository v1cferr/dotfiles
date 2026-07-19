# Anotações

> 1. Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)
> 2. Nas arquivos de configurações `.nix`, `.lua`, `.conf` e etc. Adicionar apenas uma linha de comentário `# exemplo` (resumo) para cada config logo acima para resumir o que exatamente aquela linha faz (para não poluir os arquivos de configurações de comentários)

- [ ] Instalar o flameshot — DEPOIS no SSD (precisa compilar c/ enableWlrSupport;
      lento no HDD). Alternativa nativa sem compilar: grim + slurp + swappy.
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [ ] Adicionar um software para notificações
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/theme.nix)
  - [ ] Tema Windows 11 no file manager — DEPOIS no SSD (cosmético, ajuste visual
        no Kvantum Manager). Caminho: instalar kdePackages.qtstyleplugin-kvantum +
        vendorizar tema Win11 Kvantum (ex.: store.kde.org/p/1554628 "Win11OS-dark")
        em ~/.config/Kvantum + QT_STYLE_OVERRIDE=kvantum. Só estiliza o INTERIOR do
        Dolphin (a moldura é do Hyprland).

Ambos com systemd (ou algo semelhante) e rodando em daemon (background):

- [ ] Adicionar o servidor de Midia (Jellyfin) com linguagem Nix
- [ ] Adicionar o duolingo rodando para fazer automaticamente com Nix
