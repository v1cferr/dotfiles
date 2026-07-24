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
        — Ollama NATIVO (system/ai/ollama.nix) segue a my.gpu: CUDA na RTX 3050, CPU no Intel Arc.
        qwen3:4b (solver texto) + bge-m3 (embeddings) via loadModels. É o solver
        local do duo-streak-daemon (localhost:11434), sem cota nem nuvem.

## Pacotes e softwares

- [x] Media player — VLC (GUI completa, toca tudo out-of-the-box). home/media.nix
      (movido do system/ → regra: app de usuário no home).

## Games e Jogos

- [x] Bottles é declarativo? O APP sim (system/default.nix, com override removeWarningPopup).
      O que está DENTRO (bottles/prefixos, jogos, runners GE-Proton) é ESTADO em
      ~/.local/share/bottles — não declarável, vai por backup (regra: Nix = app+config; estado = restic).
- [x] Emulador — RPCS3 (PS3) no system/ p/ Uncharted 1/2/3 (trilogia é PS3). PS4/U4 só
      via shadPS4 (experimental). Firmware+jogos = estado (você provê). Controle Machenike
      G5 Pro: kernel 6.18 tem o driver xpad (nativo desde 6.10) + Bluetooth já ligado →
      só parear (runtime, bluetoothctl) e usar em modo Xbox/Xinput. Tudo declarativo possível feito.

## Segurança, Privacidade e Economia de Energia

- [x] Lockscreen & AFK/Idle mode — ver "Outros" (hyprlock + hypridle: lock aos
      5 min + tela off via dpms). Falta só desligar os LEDs no AFK (abaixo).
- [ ] Desligar todos os leds de todos os hardwares no modo AFK

## Outros

- [x] Filtro de luz azul — hyprsunset (nativo do Hyprland, CTM: não sai em
      screenshot/gravação). Serviço systemd --user + perfis por horário em
      home/hyprsunset.nix; overrides manuais no F9 (home/hypr.nix). Schedule
      herdado dos dotfiles do Arch.
- [x] Pacotes: home-manager vs system — REGRA (bate com a comunidade NixOS e com
      o cabeçalho do home/default.nix): app/config de USUÁRIO no home/ (programs.*
      quando há módulo, senão home.packages); nível-sistema (serviços/drivers/root)
      no system/. NUNCA o mesmo pacote nos dois. Como HM é módulo do NixOS
      (useGlobalPkgs+useUserPackages), 1 rebuild aplica os dois e o unfree é herdado.
      PENDENTE (migração à parte): apps GUI ainda no system/packages.nix
      (chrome/spotify/obsidian/vscode/bitwarden/qbittorrent-GUI…) → mover p/ home/.
      VLC já migrado como piloto.
- [ ] Migrar meus bindings das configs do Arch Linux (Hyprland)
- [x] Lockscreen — [hyprlock](https://github.com/hyprwm/hyprlock) + hypridle,
      portados do Arch e 100% declarativos (home/lockscreen.nix). SEM scripts .sh
      soltos: a lógica mora no BUILD (Nix) ou no systemd, runtime = comando de 1
      linha. Widgets: relógio + data pt-BR + usuário + frase (quotes.tsv → pango
      no build; `shuf -n1`) + clima (wttr.in via timer systemd; `cat` do cache).
      Idle: lock aos 5 min + tela off via dpms NATIVO (testar — no Arch o driver
      antigo congelava; fallback = gamma, no histórico git). PAM em
      system/desktop.nix (sem ele não desbloqueia); locale pt_BR em system/core.nix.
      SUPER+L tranca na hora. Notifs ficou de fora (depende do Quickshell).
- [ ] Trocar a RTX 3050 → Intel Arc B580 (Battlemage) — TERRENO PRONTO, plug-and-go
      (system/gpu.nix). `my.gpu` DEFAULT = "intel" (Arc: xe + Mesa, VA-API iHD) → o
      boot padrão já dá vídeo na Arc, SEM menu. NVIDIA vira só a specialisation
      "nvidia" (resgate). Battlemage OK no kernel 6.18/Mesa 25.x (>= 6.12/24.3).
      ANTES de sair (RTX ainda na máquina): `sudo nixos-rebuild BOOT` (NÃO switch —
      boot só agenda o próximo boot, não derruba a sessão nvidia atual). Dia da troca:
      desligar → trocar placa (monitores no DP/HDMI da Arc) → ligar → vídeo direto.
      Confirmar: `fastfetch` + `vainfo`. FALLBACK se não der vídeo: recolocar a RTX +
      escolher a entrada "nvidia" no menu (ou geração anterior), ou SSH de fora.
      Depois de validar: remover TUDO de nvidia + o switch (Intel puro). Ollama já
      cai p/ CPU no Intel (GPU Intel no Ollama = explorar depois).

## Media

> Adicionar todos como padrão

- [x] Image Viewer — Gwenview (KDE) + kimageformats/qtimageformats p/ formatos
      modernos (AVIF/HEIF/JXL/WebP/RAW). Tematizado pelo Kvantum, integra c/ Dolphin.
      home/media.nix; default de image/* via xdg.mimeApps.
- [x] PDF Viewer — Okular (KDE): PDF/EPUB/CBZ + anotações. home/media.nix;
      default de application/pdf via xdg.mimeApps.
- [x] Video Player — VLC (GUI, default de video/*) + mpv (leve/scriptável, via
      programs.mpv). home/media.nix. mpv abre manual/CLI; trocar o default é 1 linha.
- [x] Resolução dos 2 monitores + adaptação de desconexão (home/hypr.nix) —
      DP-1 (LG ULTRAGEAR) principal na origem 0x0; TV (HDMI-A-1) em 1366x768
      NATIVO à esquerda (-1366x0). A TV é painel "HD" (768p), não Full HD: 1080p
      nela só fazia downscale/borrava → nativo fica nítido. Principal em 0x0 =
      se a TV desconectar, o LG segue sozinho sem offset (ws 5–8 recaem nele).

## SpendFlow

- [ ] Configurar para ser indexado e aparecer nos primeiro resultado do Google (SEO/AIO Ranking)