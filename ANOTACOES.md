# Anotações

## Regras

> 1. Sempre pesquisar as boas práticas e o que a comunidade do NixOS está usando mais para cada pacote/software (para ter uma referência e sugestões)
> 2. COMENTÁRIO em `.nix`/`.lua`/`.conf`: uma linha de resumo por config, logo acima dela — e um BLOCO de cabeçalho por módulo, dizendo o que é, POR QUE essa escolha e as pegadinhas conhecidas. A linha evita poluir; o bloco é o que devolve horas quando o problema volta em seis meses. Comentário registra o porquê e a armadilha, não o óbvio que o código já diz. (A regra antiga proibia o bloco, mas o repo sempre teve — a regra estava errada, não a prática.)
> 3. Sempre declarativo e não "manual" (para funcionar em qualquer hardware posteriormente)
> 4. Separar `system/` e `home/`: nível-sistema (serviços, drivers, pacotes de root) no `system/`; app **e** config de usuário no `home/` (`programs.*` quando há módulo, senão `home.packages`). Nunca o mesmo pacote nos dois.
> 5. Organizar por categoria: cada assunto numa subpasta com seu `default.nix` (adicionar módulo = 1 linha no `default.nix` da categoria; o topo não muda).
> 6. Nix = app + config; estado = restic: saves, prefixos Wine, tokens/sessões de app **não** se declaram — vão pro backup.
> 7. Sem `.sh` solto: a lógica mora no build (Nix) ou no systemd; runtime = comando de 1 linha (shellcheck no build pega erro cedo).
> 8. Validar antes de aplicar: `nixos-rebuild build` / `nix eval` OK e commits atômicos por feature/task, antes do switch.
> 9. Tudo em tema TokyoNight, centralizado numa PALETA NIX própria (`home/desktop/palette.nix`, opção `my.theme.name`) — trocar de tema = 1 linha (presets: tokyo-night/catppuccin-mocha/gruvbox-dark). O nix-colors foi DESCARTADO: arquivado (abr/2026) + base16 de só 16 cores não reproduz os hexes exatos.
> 10. A FONTE de UI tem SSOT PRÓPRIA, separada das cores: `my.fonts.ui` em `system/hardware/fonts.nix` (junto do pacote, porque fonte é nível-sistema — regra 4; e o fontconfig também precisa do nome, e módulo de sistema não lê opção do home-manager). Trocar de fonte = 1 linha + o pacote. Consumidor de usuário lê via `osConfig.my.fonts.ui`, nunca literal.
> 11. SSOT SEMPRE: valor repetido em 2+ lugares vira opção `my.<domínio>.<coisa>` e consumidor NUNCA guarda literal — hoje são `my.theme.name`/`.palette` (cores, regra 9), `my.fonts.ui` (fonte, regra 10) e `my.services.<n>` (serviços opcionais). A opção mora no nível MAIS BAIXO que precisa dela: se algum módulo do `system/` consome, ela é de sistema e o `home/` lê via `osConfig` — o contrário NÃO existe (módulo de sistema não lê opção do home-manager). Consumidor de HOT-RELOAD (Quickshell/Hyprland) não aceita interpolação do Nix, porque a árvore é symlink: o módulo GERA um arquivo de dados (JSON/Lua) que ele lê, e aí o único literal legítimo é o fallback de "arquivo faltou". VALIDAR trocando a opção por um SENTINELA — rebuild, conferir que TODOS os consumidores mudaram, reverter e checar que o store path voltou idêntico.
> 12. SEGREDOS são camada SEPARADA e o repo NUNCA guarda credencial: origem = Bitwarden, entrega = sops-nix (chave age do root). Consumidor lê `/run/secrets/<nome>` em RUNTIME, nunca em tempo de build — o `/nix/store` é world-readable, então segredo interpolado em derivação VAZA. Editar segredo exige `rebuild`, senão o `/run/secrets` não atualiza.
> 13. O `flake.lock` FIXA o universo de dependências: sem `nix-channel`, sem fetch sem hash, sem "latest" implícito. Bump só por `update`/`upgrade` — o `update` roda como USUÁRIO porque é quem tem a chave SSH dos inputs privados — e o lock entra no MESMO commit da mudança que o exigiu, senão o build de ontem não é reproduzível hoje.
> 14. UM DONO por artefato: se o Nix gera o arquivo, só o Nix escreve nele; se o app o reescreve em runtime, o Nix NÃO o gerencia como arquivo — usa activation idempotente ou marcador de imutabilidade (`ViewMode[$i]`). Duas camadas no mesmo arquivo = DRIFT SILENCIOSO, o pior tipo: nada falha, só fica errado. Casos reais deste repo: hyprpaper (módulo do HM gerando formato velho contra a config que o daemon exigia → tela preta por meses), `~/.config/theme/*` (apagados como "temporários" quando eram symlinks do HM → boot sem sessão), `dolphinrc` (o Dolphin reescreve → activation + `[$i]`).
> 15. Toda AUTOMAÇÃO tem dono explícito e ÚNICO: quem inicia está declarado (unit systemd, `exec-once` do compositor, timer). Processo órfão parenteado a um shell qualquer morre com ele. E dono único SEM FALLBACK é ponto de falha: se a automação sustenta acesso remoto, precisa de rede de segurança independente da config que pode quebrar (foi o caso do `graphical-session.target`, que só o `exec-once` levantava).

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
- [x] SSOT (regra 11) — FEITO: `my.monitors.{primary,secondary}` em home/desktop/monitors.nix
      (era DP-2 em 8 arquivos e HDMI-A-3 em 7, entre Nix/Lua/QML), `my.theme.iconTheme` e
      `my.theme.cursor.{name,size}` em palette.nix, e o BURACO do kitty (themeFile fixo em
      tokyo_night — trocar `my.theme.name` recolorava tudo MENOS o terminal) corrigido mapeando
      preset → themeFile. Cada um validado com SENTINELA: troca o valor, confere que TODOS os
      consumidores mudaram, reverte e checa que o store path voltou idêntico.
      Achado no caminho: existiam DUAS implementações de `screenDP1` no Quickshell — a do Bar.qml
      procurava "DP-2" (certa) e a do Theme.qml procurava "DP-1", que NÃO existe nesta máquina →
      nunca casava, caía no fallback s[0] e notificação/OSD/PowerMenu/Mpris podiam abrir NA TV.
      Unificado em `Theme.screenPrimary`, lendo a SSOT.
- [ ] SSOT pendente — só sobrou o HOME `/home/v1cferr` (5 arquivos: dolphin.nix, Theme.qml,
      restic.nix, fai-workstation-mount.nix, home/default.nix) → `my.user.home`. Prioridade BAIXA
      de propósito: ao contrário de fonte/cor/conector, o caminho não muda quando o hardware muda.
- [x] Sessão remota resiliente (29/07) — quem sobe o `hyprland-session.target` é o exec-once do
      autostart.lua, e "autostart" vem DEPOIS de "monitors" na ordem de carga: config Lua que
      estoura = target nunca sobe = máquina sem Sunshine e sem Quickshell, com o Hyprland vivo.
      Remotamente é irrecuperável. Agora um TIMER (30s) checa e sobe o target por conta própria,
      derivando HYPRLAND_INSTANCE_SIGNATURE e WAYLAND_DISPLAY DO FILESYSTEM.
      Path unit NÃO serve: `PathExistsGlob` re-dispara enquanto a condição é verdadeira → o oneshot
      sai, o socket ainda está lá, dispara de novo, até `unit-start-limit-hit` (a 1ª versão subiu
      `failed` e a proteção não existia de fato).
      E os módulos Lua agora carregam os dados gerados pelo Nix com `pcall` + fallback INLINE por
      arquivo (não helper global: o Hyprland não compartilha globais entre os `dofile` — tentar
      isso pôs o compositor em emergency mode apontando monitors.lua).
      LIÇÃO: unidade systemd e config de compositor NÃO se validam por build, só por execução.
      `nixos-rebuild build` passa e o runtime falha.
- [x] `hyprctl -i 0` nos aliases (29/07) — o `rebuild`/`upgrade` terminavam em `&& hyprctl reload`,
      que EXIGE HYPRLAND_INSTANCE_SIGNATURE e por isso nunca funcionava por SSH: rebuildar de fora
      deixava a config nova no disco sem aplicar, calado. `-i 0` acha a instância de qualquer shell.
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
  - [x] **packet_size=1024 — OBRIGATÓRIO porque o acesso é pela tailnet** (29/07). Sintoma: o
        Moonlight conectava, pareava, o host streamava sem UM erro (monitor selecionado,
        h264_vaapi criado, Opus pronto, 18 MB de vídeo saindo) e o cliente desconectava em ~4 s,
        sempre. Causa: a tailscale0 tem MTU 1280 e o default do Sunshine é 1392 → todo pacote de
        vídeo estoura o túnel, e o WireGuard descarta em SILÊNCIO (sem ICMP, sem log, sem
        contador). O host parece perfeito e o cliente recebe frames pela metade. Estava latente
        desde sempre; 1024 cabe com folga depois de IP+UDP+cabeçalhos do Moonlight.
  - [x] Healthcheck do handler HTTPS (29/07) — o Sunshine ficou com a 47984 aceitando TCP e NUNCA
        completando o handshake TLS (22 conexões em CLOSE-WAIT), enquanto a 47989 respondia 200.
        O Moonlight usa a HTTPS em host pareado → mostrava "offline". O serviço ficava `active`,
        ExecMainStatus=0 e SEM UMA LINHA de log: invisível por definição. Timer de 2 min tenta o
        handshake e reinicia após 3 falhas em ~10 s. PEGADINHA que quase foi pro repo: `| grep -q`
        com o `set -o pipefail` do writeShellApplication INVERTE o resultado (grep sai no 1º match,
        openssl morre de SIGPIPE, pipeline retorna erro APESAR do match) — a 1ª versão lia
        handshake OK como falha e reiniciava o Sunshine a cada 2 min. Captura em variável + `case`.
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
- [x] Wallpaper — **hyprpaper** (oficial do Hyprland, estático/leve) + imagens do nixos-artwork
      (via pkgs: sem binário no git, bump junto do nixpkgs; o .gitignore barra *.png de propósito).
      Principal = catppuccin-mocha, TV = moonscape — as MESMAS duas do lockscreen, então
      desbloquear não troca o fundo por baixo. home/desktop/wallpaper.nix. 34 opções em
      `nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`; existem os
      `nineish-catppuccin-*`, que não existiam quando isto foi configurado.
      ATENÇÃO — este item ficou marcado [x] por meses SEM FUNCIONAR (a tela era preta, ver o item
      de correção abaixo). Documentação afirmando que algo funciona é pior que TODO em aberto: fez
      duvidar de renderização/GPU em vez de olhar o formato da config.
      (Alternativas p/ referência: swww = transições/rotação; mpvpaper = vídeo.)
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
        `8c:86:dd:61:22:12` (enp7s0, cabeada). Wake-on-LAN AGORA MONTADO (antes era
        "não vale, a máquina não desliga"): `wake-workstation`, em home/net/fai-workstation.nix,
        com duas estratégias — unicast pelo túnel + broadcast dirigido da /25 localmente, e RELAY
        rodando na fai-vm, que está na mesma sub-rede e faz broadcast L2 de verdade (o SonicWall
        não passa magic packet). Magic packet em Python, não o `wakeonlan` do nixpkgs (Perl, que
        arrasta Perl-Critic/Perl-Tidy pro build) — e é o MESMO código do relay, onde não se
        instala nada. SO_BROADCAST é obrigatório; portas 9 e 7 porque NIC velha às vezes só ouve
        a 7. AINDA NÃO TESTADO de ponta a ponta: a workstation não desliga, então não houve
        ocasião de observar o efeito.
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
- [x] "Wallpaper preto" (29/07) — CAUSA RAIZ: o hyprpaper 0.8 trocou o formato da config, do
      achatado (`wallpaper = MONITOR,path` + `preload =` + `ipc =`) p/ CATEGORIA
      (`wallpaper { monitor = …; path = …; }`). `preload` e `ipc` não existem mais nem como string
      no binário (`strings hyprpaper | grep -c preload` = 0). O módulo services.hyprpaper do
      home-manager AINDA gera o formato antigo → o daemon sobe, acha os 2 outputs e loga
      "Monitor DP-2 has no target: no wp will be created": nenhuma layer surface, fundo preto e
      NENHUM erro de parse denunciando. Diagnóstico: `hyprctl layers` mostrava só a layer do
      quickshell, nunca a do hyprpaper. FIX: a config passa a ser escrita por xdg.configFile e o
      módulo fica só com `enable` (serviço + pacote).
      Também: `pathOf` deriva o NOME DO ARQUIVO lendo o pacote, porque não há padrão — a maioria é
      `nix-wallpaper-<attr>.png`, os catppuccin são `nixos-wallpaper-<attr>.png` e o gradient-grey é
      NixOS-Gradient-grey.png. Antes, "trocar = 1 attr" era mentira e quebraria num catppuccin.
