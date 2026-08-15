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

  # Os três aliases de manutenção são compostos aqui e não escritos três vezes: `upgrade`
  # É `update && rebuild` por definição, e restatá-lo por extenso (como era até 06/08/2026)
  # é a mesma regra em dois lugares — no dia em que só uma das cópias muda, `upgrade` para
  # de ser o que o nome diz e ninguém percebe (regra 11).
  rebuildCmd = "nh os switch ${flake} && { hyprctl -i 0 reload || true; }";
  # vscode-bump ANTES do flake update: o input `vscode-tarball` tem URL VERSIONADA (o
  # porquê está no flake.nix), então é ele quem sobe o número — é o que faz o VS Code
  # ficar sempre na última stable. NO-OP quando já está. Falhou (API fora, repo em outro
  # formato)? O `&&` para aqui e nada é aplicado com o repo meio-editado.
  # O `vscode-extensions-dump` vai por ÚLTIMO e não mexe em input nenhum: ele regrava o
  # espelho das extensões instaladas (home/apps/vscode/extensions.txt) pra que o repo mostre
  # no diff extensão que entrou ou saiu. O gatilho é este alias, e não o `rebuild`, porque
  # `update` é o ritual de manutenção — o preço é o espelho ficar atrasado entre dois
  # `update`, o que é aceitável pra um registro que ninguém consome em runtime.
  # curseforge-bump ao lado do vscode-bump, e pelo mesmo motivo com um agravante: o src do
  # CurseForge é URL-PONTEIRO (a Overwolf não publica URL versionada), então não basta
  # trocar um número — o HASH precisa ser recalculado, senão a próxima release deles
  # quebra o build em store fria. Custa um range request de 256 KiB quando nada mudou.
  updateCmd = "vscode-bump ${flake} && curseforge-bump ${flake} && nix flake update --flake ${flake} && vscode-extensions-dump ${flake}";
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
      rebuild = rebuildCmd;
      update = updateCmd; # bump do flake.lock + da versão do VS Code (vscode-bump)
      # upgrade = update + rebuild (tipo `apt update && apt full-upgrade`). O `update` roda
      # como USUÁRIO primeiro (tem a chave SSH p/ inputs privados, ex. duo-streak-daemon) e
      # SÓ com sucesso (`&&`) segue pro rebuild como root — lock quebrado nunca chega a aplicar.
      upgrade = "${updateCmd} && ${rebuildCmd}";
      # CUIDADO com o `-d`: ele apaga TODAS as gerações antigas, não só as velhas — ou seja,
      # depois de rodar não há mais rollback p/ a geração de ontem, nem entrada dela no GRUB.
      # É o que se quer quando a intenção é liberar o máximo; se a intenção for só higiene,
      # `--delete-older-than 7d` limpa quase o mesmo e PRESERVA a saída de emergência.
      # (O GC automático semanal, esse sim, usa --delete-older-than 30d — system/core/core.nix.)
      gc = "sudo nix-collect-garbage -d"; # limpa gerações antigas da store manualmente

      # ACHAR UM ARQUIVO DENTRO DO BACKUP. Monta o repo como pasta read-only com um
      # diretório por snapshot (`snapshots/latest/…`) — abre no Dolphin e navega.
      # Ctrl+C desmonta. O repo é blob CIFRADO: quem decifra é o restic, não o rclone.
      #
      # SEM `sudo`, e isso é o ponto: mount FUSE é privado de quem montou, então
      # `sudo restic mount` gera uma pasta que o Dolphin NÃO abre (era o defeito da 1ª
      # versão). Rodando como usuário, a pasta é dele e o file manager entra. Exige as
      # senhas legíveis sem sudo — feito em system/core/secrets.nix — e o mountpoint
      # criado por tmpfiles em system/services/restic.nix.
      #
      # Alias e não script (regra 7): é comando de uma linha.
      #
      # Só sobrou o do HOME. O gêmeo `arch-browse` (acervo do Arch antigo) MORREU em
      # 11/08/2026: aquele mount virou permanente e tem dono declarado agora
      # (home/services/arch-legacy-mount.nix) — /mnt/arch-antigo já está montado, não há
      # comando pra rodar. Este aqui segue sob demanda de propósito: o repo do HOME é
      # justamente o que a poda diária precisa travar sozinha.
      backup-browse = "RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf restic -r rclone:gdrive:BACKUPS_EX-B560M-V5/HOME --password-file /run/secrets/restic_password mount /mnt/backup";
      # Relê TODOS os dados do repo pra provar que dá pra restaurar (baixa o repo inteiro
      # — ~24 GiB, ~4 min). É deliberadamente manual: no automático seria download diário.
      backup-verify = "sudo restic-home-gdrive check --read-data";

      # ls/ll/la/lt (eza) e cat (bat) vivem em home/cli.nix, junto do toolkit CLI
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
