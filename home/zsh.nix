# CONFIG do zsh (~/.zshrc), declarado. O shell de LOGIN vira zsh no system/default.nix
# (users.users.v1cferr.shell + programs.zsh.enable — o NixOS exige o enable system-wide
# pra /etc/shells e o ambiente base). Aqui é só o comportamento interativo. O prompt é
# o starship (home/starship.nix) e o terminal é o kitty (home/kitty.nix).
{ ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true; # completar comandos/paths com Tab (compinit)
    autosuggestion.enable = true; # sugere comando do histórico em cinza (→ aceita)
    syntaxHighlighting.enable = true; # colore na hora (verde = existe / vermelho = não)
    autocd = true; # digitar só o path já faz o cd (sem escrever `cd`)

    history = {
      size = 50000; # linhas mantidas em memória na sessão
      save = 50000; # linhas gravadas no arquivo de histórico
      ignoreDups = true; # não guarda duplicata consecutiva
      ignoreAllDups = true; # ao repetir, remove a ocorrência antiga
      ignoreSpace = true; # comando iniciado por espaço não entra no histórico
      expireDuplicatesFirst = true; # ao podar, mata duplicata antes de comando único
      share = true; # histórico compartilhado entre abas/terminais em tempo real
    };

    shellAliases = {
      # NixOS: sem `#host` o nixos-rebuild casa o hostname atual com o nixosConfigurations.
      rebuild = "sudo nixos-rebuild switch --flake ~/Projects/GitHub/v1cferr/dotfiles";
      update = "nix flake update --flake ~/Projects/GitHub/v1cferr/dotfiles"; # bump do flake.lock
      gc = "sudo nix-collect-garbage -d"; # limpa gerações antigas da store manualmente
      ll = "ls -lah"; # listagem detalhada + arquivos ocultos + tamanhos legíveis
      la = "ls -A"; # lista tudo (menos . e ..)
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
