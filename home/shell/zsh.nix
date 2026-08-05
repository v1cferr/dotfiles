# CONFIG do zsh (~/.zshrc), declarado. O shell de LOGIN vira zsh no system/default.nix
# (users.users.v1cferr.shell + programs.zsh.enable — o NixOS exige o enable system-wide
# pra /etc/shells e o ambiente base). Aqui é só o comportamento interativo. O prompt é
# o starship (home/starship.nix) e o terminal é o kitty (home/kitty.nix).
{ osConfig, ... }:

let
  # SSOT do caminho do repo: `programs.nh.flake` em system/core/core.nix (regra 11 — a
  # opção mora no nível mais baixo que precisa dela, e o home lê via osConfig). Antes
  # este caminho era literal nos três aliases abaixo.
  flake = osConfig.programs.nh.flake;
in
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
      # `nh os switch` no lugar do `sudo nixos-rebuild switch`: árvore de progresso do
      # build (nix-output-monitor por dentro) + DIFF de pacotes entre a geração atual e a
      # nova. SEM `sudo` na frente de propósito — o nh eleva sozinho na hora de ativar,
      # então o build roda como usuário e só a ativação pede senha.
      #
      # O CAMINHO VAI EXPLÍCITO, e não via NH_FLAKE. Aprendido na prática em 03/08/2026:
      # o `programs.nh.flake` publica a variável por `environment.variables`, que vira
      # `export` no /etc/set-environment e só é lido no LOGIN. A sessão gráfica em curso
      # não a tem, e terminal novo herda o ambiente da sessão (não relê o /etc/profile) —
      # então o alias quebrava exatamente depois do switch que o introduziu, com a
      # mensagem enganosa "no flake found at /etc/nixos/flake.nix", como se a config
      # estivesse no lugar errado. Passando o caminho, funciona no primeiro `rebuild` e
      # não depende de relogar. O programs.nh.flake CONTINUA valendo (é a SSOT lida aqui,
      # e serve pro `nh` avulso), só não é mais dependência do alias.
      rebuild = "nh os switch ${flake} && { hyprctl -i 0 reload || true; }";
      update = "nix flake update --flake ${flake}"; # bump do flake.lock
      # upgrade = update + rebuild (tipo `apt update && apt full-upgrade`). O `update` roda
      # como USUÁRIO primeiro (tem a chave SSH p/ inputs privados, ex. duo-streak-daemon) e
      # SÓ com sucesso (`&&`) segue pro rebuild como root — lock quebrado nunca chega a aplicar.
      upgrade = "nix flake update --flake ${flake} && nh os switch ${flake} && { hyprctl -i 0 reload || true; }";
      # CUIDADO com o `-d`: ele apaga TODAS as gerações antigas, não só as velhas — ou seja,
      # depois de rodar não há mais rollback p/ a geração de ontem, nem entrada dela no GRUB.
      # É o que se quer quando a intenção é liberar o máximo; se a intenção for só higiene,
      # `--delete-older-than 7d` limpa quase o mesmo e PRESERVA a saída de emergência.
      # (O GC automático semanal, esse sim, usa --delete-older-than 30d — system/core/core.nix.)
      gc = "sudo nix-collect-garbage -d"; # limpa gerações antigas da store manualmente

      # ACHAR UM ARQUIVO DENTRO DO BACKUP. Monta o repo do Drive como pasta read-only,
      # um diretório por snapshot (`snapshots/latest/…`) — abre no Dolphin e navega.
      # Ctrl+C desmonta. O repo é blob CIFRADO: quem decifra é o restic, não o rclone.
      # Vale como alias e não script (regra 7): é comando de uma linha, e o wrapper
      # `restic-home-gdrive` (gerado pelo módulo) já leva senha, RCLONE_CONFIG e rclone.
      backup-browse = "sudo mkdir -p /mnt/backup && sudo restic-home-gdrive mount /mnt/backup";
      # Relê TODOS os dados do repo pra provar que dá pra restaurar (baixa o repo inteiro
      # — ~24 GiB, ~4 min). É deliberadamente manual: no automático seria download diário.
      backup-verify = "sudo restic-home-gdrive check --read-data";

      # ls/ll/la/lt (eza) e cat (bat) vivem em home/cli.nix, junto do toolkit CLI
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
