# Anotações

## Regras

> 1. Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)
> 2. Nas arquivos de configurações `.nix`, `.lua`, `.conf` e etc. Adicionar apenas uma linha de comentário `# exemplo` (resumo) para cada config logo acima para resumir o que exatamente aquela linha faz (para não poluir os arquivos de configurações de comentários)
> 3. Sempre declarativo e não "manual" (para funcionar em qualquer hardware posteriormente)
> 4. Separar `system/` e `home/`: nível-sistema (serviços, drivers, pacotes de root) no `system/`; app **e** config de usuário no `home/` (`programs.*` quando há módulo, senão `home.packages`). Nunca o mesmo pacote nos dois.
> 5. Organizar por categoria: cada assunto numa subpasta com seu `default.nix` (adicionar módulo = 1 linha no `default.nix` da categoria; o topo não muda).
> 6. Nix = app + config; estado = restic: saves, prefixos Wine, tokens/sessões de app **não** se declaram — vão pro backup.
> 7. Sem `.sh` solto: a lógica mora no build (Nix) ou no systemd; runtime = comando de 1 linha (shellcheck no build pega erro cedo).
> 8. Validar antes de aplicar: `nixos-rebuild build` / `nix eval` OK e commits atômicos por feature/task, antes do switch.

## Ideias

> Quickshell: DECIDIDO — migrei tudo pro Quickshell (ver TODO). Personalizável em QML
> com hot-reload; o Hyprland também virou hot-reload (hyprland.lua via mkOutOfStoreSymlink).

## TODO

- [x] Quickshell — shell/bar/OSD/mídia/NOTIFICAÇÕES em QML (portado do meu Arch,
      adaptado). Substituiu a waybar (removida) E o swaync (o Quickshell é o daemon de
      org.freedesktop.Notifications). Binário do flake oficial (latest). Config QML em
      home/desktop/quickshell/ via mkOutOfStoreSymlink → HOT-RELOAD (edita .qml e
      recarrega ao vivo; delegate de Repeater às vezes pede restart do qs, SUPER+ESCAPE).
      Adaptações Arch→NixOS: GPU nvidia→sysfs xe (só temp), hypridle→systemctl, monitores
      DP-2/HDMI-A-3, VPN dropada, Firefox→Zen.
- [x] Hyprland hot-reload + config MODULAR — hyprland.lua saiu do texto embutido pra
      arquivos reais no repo via mkOutOfStoreSymlink (edita + `hyprctl reload`, sem rebuild).
      Quebrado por categoria (regra 5) em home/desktop/hypr/lua/*.lua: environment, monitors,
      appearance, input, autostart, rules, keybinds; o hyprland.lua é só o loader (dofile na
      ordem). Scripts (minimize-others/brightness-osd/monitor-toggle) vão pro PATH; o Lua chama
      por nome. API Lua 0.55: gradiente = {colors,angle}, bezier = hl.curve, animação = hl.animation.
- [x] Monitor fantasma — serviço hypr-monitor-watch (systemd --user) escuta o socket2 e dá
      `hyprctl reload` no hotplug: mata a área fantasma (cursor na tela que sumiu) e move os
      workspaces (TV fora → ws 5-8 no LG). Caveat: TV DESLIGADA que mantém o HDMI não manda
      evento → precisaria de toggle manual.
- [x] Brilho por teclado — SHIFT+VolUp/VolDown/0 = +claro/+escuro/reset (gamma do hyprsunset;
      sem backlight real). Piso 20% (clamp) + teto 150%. OSD nativo do Quickshell via IPC.
- [x] Frases do lockscreen via API — removido o quotes.tsv; serviço+timer busca lote da
      ZenQuotes (EN) 1×/dia e TRADUZ p/ pt-BR via DeepL (chave sops deepl_api_key; só as
      frases num request em lote, autor no original) → cache pango → shuf -n1. Fallback:
      sem chave/DeepL fora ⇒ lote EN; sem rede ⇒ frase embutida. Diário p/ caber na cota
      grátis do DeepL (500k chars/mês).
- [x] Configurar o OOM Killer — earlyoom (system/hardware/oom.nix), companheiro do zram:
      mata o MAIOR processo antes do freeze por falta de RAM. --prefer browsers/Electron,
      --avoid compositor/sessão/sshd. Coexiste com o systemd-oomd (backstop). thresholds
      10%/10% (default testado); notifica via notify-send (Quickshell é o daemon).
- [x] Alterar os wallpapers da minha screenlock — trocados os do Arch pelos oficiais do
      NixOS via pkgs.nixos-artwork.wallpapers (declarativo, sem binário no git):
      principal = catppuccin-mocha (cheia), TV = moonscape. Blur/brilho ajustados
      (blur_passes 2, brightness 0.40). home/desktop/lockscreen.nix.
  - <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
- [ ] Adicionar um método de zip direto no tooltip do meu file manager (Dolphin) — zipar sem abrir o terminal, via menu de contexto (botão direito). Pesquisar se há algum software que faça isso.
- [x] Software para notificações — o Quickshell é o daemon (dono do org.freedesktop.Notifications):
      toasts + centro de controle, em QML. Substituiu o swaync/mako (dois daemons brigam pelo mesmo
      nome D-Bus). Alternativas standalone p/ referência: mako (minimalista) / swaync (com control center).
- [x] Instalar o flameshot — v14 do UNSTABLE (pkgs.unstable.flameshot, overlay do flake;
      resto do sistema fica estável) + captura via xdg-desktop-portal (Screenshot servido
      pelo portal-hyprland, que o programs.hyprland já habilita; XDG_CURRENT_DESKTOP=Hyprland).
      SEM grim direto/useGrimAdapter → some o aviso "grim ... GNOME". A ideia antiga de que
      "o portal não funcionava aqui" ficou obsoleta (o portal-hyprland passou a prover a
      interface Screenshot). Multi-monitor: windowrule estica o overlay pelas 2 telas.
      Pacote + config em home/apps/flameshot.nix.
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [x] Clipboard (Wayland) — cliphist + wl-clipboard, watcher no autostart do Hyprland
      e picker no wofi (SUPER+SHIFT+V). Pacotes E config em home/desktop/hypr.nix.
      + wl-clip-persist: mantém a cópia viva após o app fechar (fix da imagem do
      Flameshot, que sumia do clipboard ao Flameshot sair — dono do clipboard no Wayland).
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/desktop/theme.nix)
- [ ] Depois que eu estiver no SSD, já configurar o WoW Ascension com o Bottles para jogarmos e eu ir configurando o sistema simultaneamente

- [x] Verificar a arquitetura de pastas e melhores práticas para manutenção/organização/
      escalabilidade — FEITO. Reorganizado por categoria (padrão da comunidade):
      home/ → shell/ desktop/ apps/ services/ + packages.nix (lista central de apps
      de usuário); system/ → core/ hardware/ net/ desktop/ services/ + packages.nix.
      Cada subpasta tem seu default.nix. README atualizado.
- [x] Remover todos os outros hosts e manter apenas o atual — só hosts/nixos-sandisk/ (SSD SanDisk).
- [x] Instalar software para análise de uso de disco — gdu (TUI Go, ~5× mais
      rápido que ncdu em disco grande) + filelight (GUI KDE, sunburst; integra c/
      Dolphin/Kvantum). Ambos em system/packages.nix. Uso: `sudo gdu -x /`.

- [x] Tema Windows 11 no file manager — Kvantum + tema Win11OS-dark, tudo
      declarativo (home/desktop/theme.nix). O Qt deixou de seguir o GTK e passou a ser
      100% Kvantum (platformTheme+style = kvantum; a engine qtstyleplugin-kvantum
      vem pelo módulo qt). O tema é vendorizado por commit (fetchFromGitHub de
      yeyushengfan258/Win11OS-kde, só a pasta Kvantum) e instalado via
      qt.kvantum.themes → ~/.config/Kvantum. Só estiliza o INTERIOR do Dolphin
      (a moldura é do Hyprland). Ícones estilo Windows 11: fluent-icon-theme
      (Fluent-dark, agora em home/desktop/theme.nix via gtk.iconTheme.package); no
      Dolphin/KDE via kdeglobals [Icons] Theme (activation em theme.nix), nos apps GTK via dconf.

> Ambos com systemd (ou algo semelhante) e rodando em daemon (background)

- [x] Adicionar o servidor de Mídia (Jellyfin) com Nix — nativo, systemd, biblioteca em /srv/media (system/services/jellyfin.nix).
- [x] Adicionar o duolingo rodando para fazer automaticamente com Nix — stack
      duo-streak-daemon (daemon Playwright + api + web + Postgres) via docker
      compose gerenciado por systemd (system/services/duo.nix). Código = flake input
      privado (git+ssh, fixo no flake.lock); segredos via sops (template duo.env);
      login por SESSÃO salva (duo-login 1x — o headless cai no anti-bot do Duolingo).
      Ofensiva mantida sozinha 1x/dia (catch-up). Helpers: duo-login, duo-run-once.
  - [x] Instalar Ollama ou outro recomendando para rodar modelos de IA localmente
        — Ollama NATIVO (system/services/ollama.nix) roda em CPU (i5-11400; aceleração na
        Arc B580 = explorar depois). qwen3:4b (solver texto) + bge-m3 (embeddings)
        via loadModels. É o solver local do duo-streak-daemon (localhost:11434),
        sem cota nem nuvem.

- [x] Media player — VLC (GUI completa, toca tudo out-of-the-box). home/apps/media.nix
      (movido do system/ → regra: app de usuário no home).

- [x] Bottles é declarativo? O APP sim (home/packages.nix, com override removeWarningPopup).
      O que está DENTRO (bottles/prefixos, jogos, runners GE-Proton) é ESTADO em
      ~/.local/share/bottles — não declarável, vai por backup (regra: Nix = app+config; estado = restic).
- [x] Steam é declarativo? SIM, e vai em system/ (programs.steam) — é o método
      OFICIAL/recomendado (wiki NixOS + manual nixpkgs), NÃO home-manager: não
      existe programs.steam no HM. Não fere a regra 4 — a Steam é INTEGRAÇÃO de
      sistema (libs 32-bit da GPU, FHS-wrap, udev dos controles, firewall do
      Remote Play/LAN), classe do programs.hyprland, não app de usuário puro. O
      que é do usuário (jogos, login, saves) = ESTADO → restic (regra 6), já
      excluído (restic.nix:38). system/gaming/steam.nix: + Proton-GE
      (extraCompatPackages) + gamemode. Categoria nova system/gaming/ (regra 5).
      Som dos jogos OpenAL/HashLink (Northgard, Dead Cells…): o OpenAL 1.18.2
      embutido não tem backend `pipewire` → fica mudo; força backend `pulse` via
      ~/.config/alsoft.conf declarativo (home/apps/openal.nix), global p/ todos.
  - <https://wiki.nixos.org/wiki/Steam>
- [x] Emulador — RPCS3 (PS3) em home/packages.nix p/ Uncharted 1/2/3 (trilogia é PS3). PS4/U4 só
      via shadPS4 (experimental). Firmware+jogos = estado (você provê). Controle Machenike
      G5 Pro: kernel 6.18 tem o driver xpad (nativo desde 6.10) + Bluetooth já ligado →
      só parear (runtime, bluetoothctl) e usar em modo Xbox/Xinput. Tudo declarativo possível feito.

- [x] Lockscreen & AFK/Idle mode — ver "Outros" (hyprlock + hypridle: lock aos
      5 min + tela off via dpms). Falta só desligar os LEDs no AFK (abaixo).
- [ ] Desligar todos os leds de todos os hardwares no modo AFK

- [x] Filtro de luz azul — hyprsunset (nativo do Hyprland, CTM: não sai em
      screenshot/gravação). Serviço systemd --user + perfis por horário em
      home/desktop/hyprsunset.nix; overrides manuais no F9 (home/desktop/hypr.nix). Schedule
      herdado dos dotfiles do Arch.
- [x] Pacotes: home-manager vs system — REGRA (regra 4): app/config de USUÁRIO no
      home/ (programs.* quando há módulo, senão home.packages); nível-sistema
      (serviços/drivers/root) no system/. NUNCA o mesmo pacote nos dois. Como HM é
      módulo do NixOS (useGlobalPkgs+useUserPackages), 1 rebuild aplica os dois e o
      unfree é herdado. MIGRAÇÃO CONCLUÍDA: todos os apps GUI/CLIs saíram do
      system/packages.nix → lista central home/packages.nix + módulos com config
      próprios (kitty/dolphin/flameshot/media/quickshell/tema/hypr helpers). system/
      ficou só com resgate/base/diagnóstico. (git/vim ficam nos dois de propósito:
      root/rescue vs programs.git — única exceção consciente.)
- [x] Migrar meus bindings das configs do Arch Linux (Hyprland) — FEITO. Binds + look-and-feel
      (bordas com gradiente Tokyo Night, blur, shadow, animações completas) e input (mouse accel
      flat, numlock, ABNT2) portados do Arch pra Lua modular (home/desktop/hypr/lua/). Ver acima.
- [x] Lockscreen — [hyprlock](https://github.com/hyprwm/hyprlock) + hypridle,
      portados do Arch e 100% declarativos (home/desktop/lockscreen.nix). SEM scripts .sh
      soltos: a lógica mora no BUILD (Nix) ou no systemd, runtime = comando de 1
      linha. Widgets: relógio + data pt-BR + usuário + frase (ZenQuotes via timer,
      traduzida p/ pt-BR pelo DeepL → cache pango; `shuf -n1`) + clima (wttr.in via
      timer systemd; `cat` do cache).
      Idle: lock aos 5 min + tela off via dpms NATIVO (testar — no Arch o driver
      antigo congelava; fallback = gamma, no histórico git). PAM em
      system/desktop/desktop.nix (sem ele não desbloqueia); locale pt_BR em system/core/core.nix.
      SUPER+L tranca na hora. Notifs agora são do Quickshell (daemon nativo).
- [x] Trocar a RTX 3050 → Intel Arc B580 (Battlemage) — FEITO. Arc validada (`xe`
      carregado, fastfetch/vainfo OK) e NVIDIA REMOVIDA de vez: system/hardware/gpu.nix agora
      é Intel puro (xe + Mesa, VA-API iHD), sem `my.gpu`, sem specialisation, sem CUDA.
      Battlemage OK no kernel 6.18/Mesa 25.x. Ollama caiu p/ CPU (system/services/ollama.nix;
      GPU Intel no Ollama = explorar depois). Pra ressuscitar a NVIDIA: histórico git
      do system/hardware/gpu.nix.

> Adicionar todos como padrão

- [x] Image Viewer — Gwenview (KDE) + kimageformats/qtimageformats p/ formatos
      modernos (AVIF/HEIF/JXL/WebP/RAW). Tematizado pelo Kvantum, integra c/ Dolphin.
      home/apps/media.nix; default de image/* via xdg.mimeApps.
- [x] PDF Viewer — Okular (KDE): PDF/EPUB/CBZ + anotações. home/apps/media.nix;
      default de application/pdf via xdg.mimeApps.
- [x] Video Player — VLC (GUI, default de video/*) + mpv (leve/scriptável, via
      programs.mpv). home/apps/media.nix. mpv abre manual/CLI; trocar o default é 1 linha.
- [x] Resolução dos 2 monitores + adaptação de desconexão (home/desktop/hypr.nix) —
      DP-2 (LG ULTRAGEAR) principal na origem 0x0; TV (HDMI-A-3) à esquerda. Principal
      em 0x0 = se a TV desconectar, o LG segue sozinho sem offset (ws 5–8 recaem nele).

- [ ] Configurar para ser indexado e aparecer nos primeiro resultado do Google (SEO/AIO Ranking)
- [ ] Organizar meu markdown de anotações
- [ ] Adicionar um método de zip direto no tooltip do meu file manager (Dolphin) — zipar sem abrir o terminal, via menu de contexto (botão direito). Pesquisar se há algum software que faça isso.
- [ ] Adicionar um arquivo para declarar quais softwares inicializam e ficam ativos com a minha maquina (preciso ter esse acompanhamento)
