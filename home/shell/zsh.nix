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
      # && hyprctl -i 0 reload: recarrega o hyprland.lua (config nova não aplica sozinha).
      # O `-i 0` é o que faz isso funcionar por SSH: sem ele o hyprctl exige
      # HYPRLAND_INSTANCE_SIGNATURE, que só existe dentro da sessão gráfica → rebuildar de
      # fora falhava calado e a config nova NÃO era aplicada (29/07). O `|| true` mantém o
      # exit code do rebuild como o que importa, mesmo sem Hyprland rodando.
      rebuild = "sudo nixos-rebuild switch --flake ~/Projects/GitHub/v1cferr/dotfiles && { hyprctl -i 0 reload || true; }";
      update = "nix flake update --flake ~/Projects/GitHub/v1cferr/dotfiles"; # bump do flake.lock
      # upgrade = update + rebuild (tipo `apt update && apt full-upgrade`). O `update` roda
      # como USUÁRIO primeiro (tem a chave SSH p/ inputs privados, ex. duo-streak-daemon) e
      # SÓ com sucesso (`&&`) segue pro rebuild como root — lock quebrado nunca chega a aplicar.
      upgrade = "nix flake update --flake ~/Projects/GitHub/v1cferr/dotfiles && sudo nixos-rebuild switch --flake ~/Projects/GitHub/v1cferr/dotfiles && { hyprctl -i 0 reload || true; }";
      gc = "sudo nix-collect-garbage -d"; # limpa gerações antigas da store manualmente
      # ls/ll/la/lt (eza) e cat (bat) vivem em home/cli.nix, junto do toolkit CLI
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
