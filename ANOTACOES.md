# Anotações

> 1. Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)
> 2. Nas arquivos de configurações `.nix`, `.lua`, `.conf` e etc. Adicionar apenas uma linha de comentário `# exemplo` (resumo) para cada config logo acima para resumir o que exatamente aquela linha faz (para não poluir os arquivos de configurações de comentários)
> 3. Sempre declarativo e não "manual" (para funcionar em qualquer hardware posteriormente)

- [x] Instalar o flameshot — v13 estável + enableWlrSupport (grim). O v14 só
      captura via portal (não funciona neste Hyprland); o v13 usa grim direto
      (useGrimAdapter). Multi-monitor: windowrule estica o overlay pelas 2 telas.
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [ ] Adicionar um software para notificações
- [x] Clipboard (Wayland) — cliphist + wl-clipboard, watcher no autostart do Hyprland
      e picker no wofi (SUPER+SHIFT+V). Pacotes no system/, config em home/hypr.nix.
      + wl-clip-persist: mantém a cópia viva após o app fechar (fix da imagem do
      Flameshot, que sumia do clipboard ao Flameshot sair — dono do clipboard no Wayland).
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/theme.nix)
- [ ] Depois que eu estiver no SSD, já configurar o WoW Ascension com o Bottles para jogarmos e eu ir configurando o sistema simultaneamente

## Mantenabilidade

- [ ] Verificar a arquitetura de pastas e melhores práticas para manunteção, organização e escalabilidade do meu repositório (dotfiles do Nix e NixOS)
- [ ] Remover todos os outros hosts e manter apenas o atual (atualmente estamos no SSD SanDisk)

## Temas (Tokyo Night e etc)

- [x] Tema Windows 11 no file manager — Kvantum + tema Win11OS-dark, tudo
      declarativo (home/theme.nix). O Qt deixou de seguir o GTK e passou a ser
      100% Kvantum (platformTheme+style = kvantum; a engine qtstyleplugin-kvantum
      vem pelo módulo qt). O tema é vendorizado por commit (fetchFromGitHub de
      yeyushengfan258/Win11OS-kde, só a pasta Kvantum) e instalado via
      qt.kvantum.themes → ~/.config/Kvantum. Só estiliza o INTERIOR do Dolphin
      (a moldura é do Hyprland). Ícones estilo Windows 11: fluent-icon-theme
      (Fluent-dark, no system/); no Dolphin/KDE via kdeglobals [Icons] Theme
      (activation em theme.nix), nos apps GTK via gtk.iconTheme + dconf.

## Serviços Docker e etc

> Ambos com systemd (ou algo semelhante) e rodando em daemon (background)

- [ ] Adicionar o servidor de Midia (Jellyfin) com linguagem Nix
- [x] Adicionar o duolingo rodando para fazer automaticamente com Nix — stack
      duo-streak-daemon (daemon Playwright + api + web + Postgres) via docker
      compose gerenciado por systemd (system/ai/duo.nix). Código = flake input
      privado (git+ssh, fixo no flake.lock); segredos via sops (template duo.env);
      login por SESSÃO salva (duo-login 1x — o headless cai no anti-bot do Duolingo).
      Ofensiva mantida sozinha 1x/dia (catch-up). Helpers: duo-login, duo-run-once.
  - [x] Instalar Ollama ou outro recomendando para rodar modelos de IA localmente
        — Ollama NATIVO com CUDA (system/ai/ollama.nix, pkgs.ollama-cuda na RTX 3050).
        qwen3:4b (solver texto) + bge-m3 (embeddings) via loadModels. É o solver
        local do duo-streak-daemon (localhost:11434), sem cota nem nuvem.

## Pacotes e softwares

- [x] Media player — VLC (GUI completa, toca tudo out-of-the-box). Pacote no system/.

## Games e Jogos

- [x] Bottles é declarativo? O APP sim (system/default.nix, com override removeWarningPopup).
      O que está DENTRO (bottles/prefixos, jogos, runners GE-Proton) é ESTADO em
      ~/.local/share/bottles — não declarável, vai por backup (regra: Nix = app+config; estado = restic).
- [x] Emulador — RPCS3 (PS3) no system/ p/ Uncharted 1/2/3 (trilogia é PS3). PS4/U4 só
      via shadPS4 (experimental). Firmware+jogos = estado (você provê). Controle Machenike
      G5 Pro: kernel 6.18 tem o driver xpad (nativo desde 6.10) + Bluetooth já ligado →
      só parear (runtime, bluetoothctl) e usar em modo Xbox/Xinput. Tudo declarativo possível feito.

## Segurança, Privacidade e Economia de Energia

- [ ] Lockscreen & AFK/Idle mode
- [ ] Desligar todos os leds de todos os hardwares no modo AFK

## Outros

- [x] Filtro de luz azul — hyprsunset (nativo do Hyprland, CTM: não sai em
      screenshot/gravação). Serviço systemd --user + perfis por horário em
      home/hyprsunset.nix; overrides manuais no F9 (home/hypr.nix). Schedule
      herdado dos dotfiles do Arch.