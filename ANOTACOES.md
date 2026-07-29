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
> 9. Tudo em tema TokyoNight, centralizado numa PALETA NIX própria (`home/desktop/palette.nix`, opção `my.theme.name`) — trocar de tema = 1 linha (presets: tokyo-night/catppuccin-mocha/gruvbox-dark). O nix-colors foi DESCARTADO: arquivado (abr/2026) + base16 de só 16 cores não reproduz os hexes exatos.
> 10. A FONTE de UI tem SSOT PRÓPRIA, separada das cores: `my.fonts.ui` em `system/hardware/fonts.nix` (junto do pacote, porque fonte é nível-sistema — regra 4; e o fontconfig também precisa do nome, e módulo de sistema não lê opção do home-manager). Trocar de fonte = 1 linha + o pacote. Consumidor de usuário lê via `osConfig.my.fonts.ui`, nunca literal.
> 11. SSOT SEMPRE: valor repetido em 2+ lugares vira opção `my.<domínio>.<coisa>` e consumidor NUNCA guarda literal — hoje são `my.theme.name`/`.palette` (cores, regra 9), `my.fonts.ui` (fonte, regra 10) e `my.services.<n>` (serviços opcionais). A opção mora no nível MAIS BAIXO que precisa dela: se algum módulo do `system/` consome, ela é de sistema e o `home/` lê via `osConfig` — o contrário NÃO existe (módulo de sistema não lê opção do home-manager). Consumidor de HOT-RELOAD (Quickshell/Hyprland) não aceita interpolação do Nix, porque a árvore é symlink: o módulo GERA um arquivo de dados (JSON/Lua) que ele lê, e aí o único literal legítimo é o fallback de "arquivo faltou". VALIDAR trocando a opção por um SENTINELA — rebuild, conferir que TODOS os consumidores mudaram, reverter e checar que o store path voltou idêntico.

## Configurações antigas do Arch Linux

> Aqui estão minhas configurações legado do Arch Linux que estamos migrando tudo para o Nix e NixOS, para que tudo seja declarativo e não manual, e para que funcione em qualquer hardware posteriormente.

- Local: `/mnt/kingston-arch/home/v1cferr/dotfiles`
- Repo no GitHub: <https://github.com/v1cferr/dotfiles>

## Ideias

> Quickshell: DECIDIDO — migrei tudo pro Quickshell (ver TODO). Personalizável em QML
> com hot-reload; o Hyprland também virou hot-reload (hyprland.lua via mkOutOfStoreSymlink).
> Para me inspirar: <https://github.com/Misterio77/Foundry>
> Wallpapers Nix: <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
> Temas centralizados: `home/desktop/palette.nix` (`my.theme`). O nix-colors foi descartado (arquivado + base16 limita a 16 cores).

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
- [x] Adicionar um método de zip direto no tooltip do meu file manager (Dolphin) — zipar sem abrir o terminal, via menu de contexto (botão direito). FEITO: kdePackages.ark (servicemenus "Comprimir/Extrair" no botão-direito). home/apps/dolphin.nix.
- [x] Software para notificações — o Quickshell é o daemon (dono do org.freedesktop.Notifications):
      toasts + centro de controle, em QML. Substituiu o swaync/mako (dois daemons brigam pelo mesmo
      nome D-Bus). Alternativas standalone p/ referência: mako (minimalista) / swaync (com control center).
- [x] Instalar o flameshot — v14 do UNSTABLE (pkgs.unstable.flameshot, overlay do flake;
      resto do sistema estável) + captura via xdg-desktop-portal, SEM grim direto/useGrimAdapter
      (some o aviso "grim ... GNOME"). PEGADINHA: o portal-hyprland 1.3.12 DECLARA mas NÃO
      implementa a interface Screenshot ("Unknown method") → precisou do xdg-desktop-portal-wlr
      (system/desktop/desktop.nix; roteamento Screenshot=wlr no portals.conf). Fluxo por TECLADO
      (o v14 força um picker de monitor no multi-monitor): SUPER+SHIFT+S abre o picker + entra no
      submap "screenshot"; 1=TV (esq), 2=principal (dir) SINTETIZAM o clique no preview do monitor
      (cursor + send_shortcut mouse:272; scripts em home/apps/flameshot.nix). A janela tem class
      VAZIA + title "flameshot" → window rule casa por TÍTULO (home/desktop/hypr/lua/rules.lua).
  - <https://wiki.nixos.org/wiki/Flameshot>
- [ ] SSOT pendente (regra 11) — o que AINDA está repetido, medido por grep no repo:
      MONITORES `DP-2` (8 arquivos) e `HDMI-A-3` (7) — wallpaper.nix, lockscreen.nix, hypr/lua
      (monitors, rules, keybinds) + hyprland.lua, desktop/default.nix e quickshell/bar/Bar.qml.
      É o pior caso e é exatamente o "entrar em 10 arquivos p/ trocar uma coisa"; candidato a
      `my.monitors.{primary,secondary}` no system/, com o Lua e o QML lendo pelo arquivo de dados
      gerado (mesmo caminho das cores).
      ÍCONES `Fluent-dark` (3: theme.nix, launcher.nix, clipboard.nix) → `my.theme.iconTheme`.
      CURSOR `Bibata-Modern-Ice` (2: theme.nix + hypr/lua/environment.lua).
      HOME `/home/v1cferr` (5: dolphin.nix, Theme.qml, restic.nix, fai-workstation-mount.nix,
      home/default.nix) → `my.user.home`, hoje hardcoded.
      BURACO REAL, não só duplicação: kitty.nix tem `themeFile = "tokyo_night_night"` FIXO, então
      trocar `my.theme.name` p/ gruvbox-dark ou catppuccin-mocha recolore tudo MENOS o terminal —
      contradiz a promessa de "1 linha" da regra 9. Corrigir mapeando preset → themeFile do kitty.
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [x] Clipboard (Wayland) — cliphist DECLARATIVO (services.cliphist, allowImages=texto+imagem)
      + picker no ROFI com PREVIEW: thumbnail das imagens copiadas + ícone por TIPO de arquivo
      (zip/vídeo/pdf/exe… via Fluent-dark), tema Tokyo Night, SUPER+SHIFT+V. Migração melhorada
      do cliphist-rofi-img.sh do Arch (script clipboard-menu). home/desktop/clipboard.nix
      (substituiu o antigo picker wofi-text). + wl-clip-persist (autostart hypr): mantém a
      cópia viva após o app fechar (fix da imagem do Flameshot — dono do clipboard no Wayland).
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/desktop/theme.nix)
- [x] Acesso remoto de tela — Tailscale (mesh WireGuard) + Sunshine/Moonlight. Sunshine
      (system/services/sunshine.nix): captura WLR (wlr-screencopy; o KMS NÃO enumera no
      driver xe da Arc) + encode na GPU Arc, acesso SÓ pela tailnet
      (openFirewall=false; a interface tailscale0 é trusted → fechado na LAN/internet). Tailscale
      (system/net/tailscale.nix): join DECLARATIVO via authKeyFile (sops/Bitwarden) — entra na
      tailnet sozinho no 1º boot, sem `tailscale up` manual. Web UI do Sunshine precisa de
      origin_web_ui_allowed=wan + csrf_allowed_origins (IP/MagicDNS da tailnet) senão o "criar
      usuário" dá erro de CSRF. Teclado: o Moonlight NÃO envia a tecla "/ ?" do ABNT2 (bug #1789)
      → ScrollLock="/" e Shift+ScrollLock="?" via hl.dsp.send_shortcut (keybinds.lua; wtype não
      injetava pelo bind). Atalhos Moonlight: Capture system shortcuts=Always p/ o SUPER passar;
      Ctrl+Alt+Shift+Z solta/recaptura o mouse, +Q sai, +X fullscreen. FOSS futuro = Headscale.
  - [x] Debug longo (jul/2026) — "tela preta no Moonlight" era o wlr capturando o monitor
        em DPMS-OFF (não regressão de versão/encoder). SOLUÇÃO: removi o dpms-off do hypridle
        (idle SÓ tranca agora) → monitor sempre aceso → nunca preto. CUIDADO: alternar dpms
        SOB captura ativa deu engine-reset da GPU (xe RCS) + page-flip wedged (só reboot limpa).
        O guard global_prep_cmd só pausa o hypridle durante o stream (não trancar no meio).
  - [x] Subir no boot — o Sunshine precisa de sessão gráfica viva → autologin (LightDM,
        defaultSession=hyprland, system/desktop/desktop.nix) + hyprlock no autostart
        (home/desktop/hypr/lua/autostart.lua) = sobe TRAVADO, o Moonlight cai no lockscreen.
  - Conecto pelo app "Low Res Desktop" (o "Desktop" simples latcha em preto por timing); o
    xrandr do prep dele NÃO é lixo — é o que dá a folga de timing. Mesma imagem 1080p.
- [x] Idioma: sistema em en-US (output/erros em inglês facilitam debug), EXCEÇÃO — a LOCKSCREEN
      é full pt-BR (data por extenso, clima, "Digite a senha…", frases via DeepL). defaultLocale=
      en_US + supportedLocales inclui pt_BR (o LC_TIME da data do lock depende dele). Teclado
      ABNT2 + timezone BR seguem (físico/fuso, não idioma). clipboard/bar/UI em en-US.
      system/core/core.nix + home/desktop/lockscreen.nix.
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
      5 min. O tela-off via dpms foi REMOVIDO — bugava o Moonlight, ver Acesso remoto).
      Falta só desligar os LEDs no AFK (abaixo).
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
      Idle: lock aos 5 min (SÓ tranca; o dpms-off foi removido — bugava o Moonlight/Arc,
      ver Acesso remoto). PAM em
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

- [x] Google Chrome canal DEV — troquei o stable pelo google-chrome-dev via flake
      nix-community/browser-previews (o nixpkgs só empacota o stable). Input novo no
      flake.nix (nixpkgs.follows p/ dedup) + home/packages.nix. Binário google-chrome-unstable;
      "latest" com `nix flake update browser-previews`. (O stable não abria por SingletonLock
      fantasma do host antigo nixos-seagate — fix: rm ~/.config/google-chrome/Singleton*.)
- [x] Alias `upgrade` (home/shell/zsh.nix) = `update` + `rebuild` num comando só (tipo
      apt full-upgrade). O update roda como USUÁRIO (chave SSH dos inputs privados) && o rebuild.
- [ ] Configurar para ser indexado e aparecer nos primeiro resultado do Google (SEO/AIO Ranking)
- [ ] Organizar meu markdown de anotações
- [x] Adicionar um método de zip direto no tooltip do meu file manager (Dolphin) — zipar sem abrir o terminal, via menu de contexto (botão direito). FEITO: kdePackages.ark (servicemenus "Comprimir/Extrair" no botão-direito). home/apps/dolphin.nix.
- [x] Adicionar um arquivo para declarar quais softwares inicializam e ficam ativos com a minha
      maquina (ligar/desligar) — FEITO: PAINEL central `system/services/toggles.nix` (`my.services.<n>`,
      mkEnableOption + mkIf/enable-gate, padrão idiomático). Flip true/false + `rebuild` liga/desliga
      10 opcionais (jellyfin, ollama, duo, sunshine, qbittorrent, restic, cloudflare-ddns, dropbox,
      discord-rpc, cs2-backup). Essenciais (tailscale/mouse/desktop/keyring/earlyoom) e VPN (sob-demanda) FORA.
- [ ] Instalar o driver/software do meu mouse Razer Deathadder v2 (adicionar a notificação de quando meu DPI mudar, etc)
- [x] Configurar meu launcher de apps (colocar icones, filtro pelos ultimos utilizados e etc)
      — FEITO: rofi `drun` (ícones Fluent-dark + fuzzy + histórico/recência) tematizado pela
      paleta única (my.theme), UI en-US. SUPER+Q (apps) / SUPER+R (bins). Saiu do wofi →
      consolidado no rofi (mesmo tool do clipboard). home/desktop/launcher.nix.
- [x] Clipboard manager com visualização de imagens/arquivos + histórico — FEITO com rofi
      (não quickshell): cliphist + rofi c/ preview (thumbnail + ícone por tipo). Ver acima.
- [x] Possibilidade de clicar para trocar de workspace na minha status bar — JÁ FEITO: os
      ws-pills têm onClicked → `hyprctl dispatch workspace <id>` (Bar.qml).
- [ ] Tray icons e tooltip clicaveis (para abrir o app ou ir para a configuração do app)
- [x] Trocar a parte do status bar que tem a logo do Arch para a logo do NixOS — FEITO:
      glifo Nerd Font U+F303 (nf-linux-archlinux) → U+F313 (nf-linux-nixos) no botão iniciar
      (PowerMenu do Quickshell). home/desktop/quickshell/bar/PowerMenu.qml.
- [x] Adicionar os wallpapers e pesquisar qual melhor Wallpaper Provider no meu caso do meu setup
      (declarativo) — FEITO: **hyprpaper** (oficial do Hyprland, estático/leve) + wallpapers do
      nixos-artwork. DP-2 = nineish-dark-gray, TV = moonscape. home/desktop/wallpaper.nix. Trocar
      imagem = 1 attr. (Alternativas p/ referência: swww = transições/rotação; mpvpaper = vídeo.)
- [ ] Arrumar o flameshot para não bugar com minha status/top bar (quickshell)
- [x] Resolver a questão do Keyring para todos os apps/softwares que precisam de senha (como o
      Dropbox, Spotify, Chrome, etc) — FEITO com keyring "Login" de senha VAZIA (seahorse: troca
      senha antiga do Arch → vazia; não-destrutivo, preserva os segredos). CAUSA RAIZ: com AUTOLOGIN
      o PAM não digita senha → pam_gnome_keyring nunca destrava; e hyprlock→keyring é comprovadamente
      quebrado no NixOS (Discourse). Senha vazia = gnome-keyring-daemon destrava sozinho no startup,
      sem prompt em nenhum app. É ESTADO (regra 6), não declarável. Doc no system/desktop/desktop.nix
      (seção Keyring). Descartados no caminho: greetd+greeter Quickshell (quebra Sunshine no boot) e
      lockscreen Quickshell (mantido hyprlock + autologin, decisão do user).
- [x] Conectar na workstation da FAI e adicionar como uma pasta com SSHFS ou algum protocolo
      semelhante e/ou mais resiliente e confiável para adicionar no meu file manager — FEITO
      com **rclone mount** (SFTP + cache VFS), NÃO sshfs (que travaria com o host VPN-gated):
      ~/FAI-workstation = raiz `/` da workstation, sobe/cai junto com a VPN FAI (vpn CLI),
      bookmark declarativo no Dolphin. home/services/fai-workstation-mount.nix.
- [x] VPN FAI + UFSCar 100% declarativas (system/net/vpn.nix) — FAI=nxBender (FOSS, 3 patches:
      ssl.wrap_socket removido no py3.12, opção `nomp` do pppd, split-tunnel) + fingerprint do
      cert self-signed; UFSCar=openconnect/GlobalProtect (`--authgroup`). Ambas split-tunnel;
      senhas via sops/Bitwarden. CLI `vpn` (connect/disconnect/status-json/menu) + binds SUPER+N /
      +SHIFT+N / +CTRL+N + PILL clicável na barra. Coexistem com o Moonlight (rotas disjuntas).
  - [x] Reconexão automática (jul/2026) — o túnel cai SOZINHO ("Modem hangup" sem SIGTERM) e com
        `Restart=no` ficava morto até reconectar na mão (12 min num dia, ~1 h em outro, derrubando
        SSH e o mount junto). Agora `Restart=always` + `RestartSec=10` nas duas, com teto de 6
        tentativas/10 min: queda real volta na 1ª, senha errada não martela o portal (SonicWall e
        GlobalProtect BLOQUEIAM a conta por tentativa repetida). `restartIfChanged=false` p/ rebuild
        não derrubar túnel em uso — o daemon-reload já aplica o `Restart=` novo no processo vivo.
        `vpn disconnect` segue OK: stop explícito não dispara restart.
  - [x] Pill que não mente (jul/2026) — `systemctl is-active` sozinho MENTE: com o portal fora do ar
        o nxBender entra em crash-loop e o systemd reporta `active` ~2 min POR TENTATIVA, com zero
        ppp0 → o pill ficava verde durante a queda inteira. `status-json` agora exige unidade ativa
        E interface do túnel presente (UFSCar filtra `tun[0-9]`, senão `type tun` casa o tailscale0).
        O `menu` fica com `is-active` DE PROPÓSITO: lá a pergunta é "o serviço roda?", p/ oferecer
        Desconectar e parar o crash-loop.
- [x] SSH declarativo p/ a workstation da FAI (home/shell/ssh.nix, `programs.ssh` API nova
      `settings`) — `ssh workstation` (200.136.209.229) + `fai-vm`, via a VPN FAI. Chave autorizada
      1x com ssh-copy-id (estado).
  - [x] Sessão que não cai (jul/2026) — o Remote-SSH do VS Code morria em buraco de rota transitório:
        medimos ~6 min de blackhole SÓ p/ a .229 com o ppp0 vivo e a fai-vm (.248) respondendo pela
        MESMA rota/túnel — ou seja, lado da FAI, sem correção possível daqui. A config agora TOLERA
        em vez de derrubar: `ServerAliveInterval 15` + `ServerAliveCountMax 20` (~5 min de folga) e
        `TCPKeepAlive no` (o keepalive do kernel derrubava ANTES desse prazo). De quebra o keepalive
        segura a sessão ociosa no SonicWall. `ControlMaster`/`ControlPersist 10m`: o Remote-SSH abre
        VÁRIAS conexões; multiplexadas num TCP só, reabrir caiu p/ 0,08 s. MAC da workstation =
        `8c:86:dd:61:22:12` (enp7s0, cabeada). Wake-on-LAN NÃO montado de propósito: a máquina não
        desliga e magic packet dificilmente atravessa o SonicWall (precisaria disparar da fai-vm).
  - TRIAGEM quando `ssh workstation` falha — testar nesta ordem: `ping 1.1.1.1` (internet),
    `nc -zv 200.133.233.101 4433` (portal da VPN), `nc -zv 200.136.209.236 443` (`fai.ufscar.br`) e
    `ip link show type ppp` (túnel). Internet OK + portal e site da FAI em timeout = INDISPONIBILIDADE
    DA FAI, não há o que ajustar aqui (já aconteceu em 29/07: `tracepath` chegava no backbone da
    UFSCar em 200.133.233.198 e morria no salto seguinte; `www.ufscar.br` de pé, FAI inteira muda).
- [x] Sistema de TEMAS centralizado (home/desktop/palette.nix, `my.theme.name`) — presets
      tokyo-night (default) / catppuccin-mocha / gruvbox-dark, hexes oficiais exatos. Trocar =
      1 linha + rebuild → recolore Quickshell (JSON via FileView), Hyprland (lua via dofile) e
      rofi/lockscreen/flameshot (leem `config.my.theme.palette`). nix-colors DESCARTADO (arquivado).
- [x] FONTE de UI centralizada (regra 10) — `my.fonts.ui` em system/hardware/fonts.nix é a SSOT;
      trocar = 1 linha + o pacote. Mora no system/ (não no my.theme) porque o PACOTE é
      nível-sistema e o fontconfig precisa do nome — sistema não lê opção do HM, o inverso sim.
      7 consumidores, todos via `osConfig.my.fonts.ui`: fontconfig (defaultFonts mono/sans/serif),
      GTK (dconf + gtk.font) e Qt em theme.nix, kitty, hyprlock, rofi launcher + clipboard, e o
      Quickshell pelo MESMO JSON da paleta (o .qml é symlink hot-reload, o Nix não escreve dentro).
      TAMANHO fica em cada consumidor (11pt GTK, 12pt kitty/rofi, por widget no lock) — é contexto.
      Validado com sentinela: troquei o valor, os 7 mudaram, o revert voltou ao mesmo store path.
      JetBrainsMono Nerd Font confirmada como a recomendação #1 p/ dev em 2026 (Fira Code = 2º,
      ligaduras; Iosevka = mais estreita, ~20% mais código/linha). PEGADINHA do rofi: dentro do
      .rasi o '#' abre literal de COR, não comentário — comentar ali mata o parse do tema INTEIRO
      e o rofi só avisa no stderr, caindo nos defaults em silêncio.
- [x] Mouse Logitech MX Master 3S (system/hardware/mouse.nix, logiops) — DPI 2222, SmartShift,
      hi-res scroll, botão de gestos → workspaces. PEGADINHA BT: boot-race + "5 tries" do HID++ →
      regra udev dispara um oneshot (sleep 5 + restart logid) que reaplica no connect/boot/wake.
- [x] Sunshine capture=wlr (system/services/sunshine.nix) — FIX do boot-hang que travava o
      Moonlight: o Sunshine probava o backend `portalgrab` no startup e pendurava no
      hyprland-share-picker → nunca abria as portas. Forçar `wlr` pula o probe do portal.
- [x] zoxide no `cd` (home/shell/cli.nix, `--cmd cd`) — `cd <parcial>` pula pra pasta mais usada;
      `cdi` = picker fzf. (o zoxide já era enable; só liguei o `--cmd cd`.)
- [x] Arrumar o meu launcher de aplicativos (mostrar icone, filtro pelos ultimos utilizados, etc)
      — DUPLICATA do launcher acima; feito (rofi drun). home/desktop/launcher.nix.
- [ ] Adicionar Wallpapers (atualmente está preto, pesquisar as melhores opções da comunidade Nix)
