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

⚠️ **O caminho `/mnt/kingston-arch` NÃO EXISTE MAIS** — o Kingston foi formatado em
01/08/2026 pra virar o daily driver NixOS. As configs do Arch agora só existem nos dois
repos restic (senha no Bitwarden: item `Restic Arch Kingston`):

| Onde                   | Repo                                                               |
| ---------------------- | ------------------------------------------------------------------ |
| Google Drive (offsite) | `rclone:gdrive:BACKUPS_EX-B560M-V5/KINGSTON` — snapshot `6d7e3ee7` |
| Seagate (local)        | `/mnt/seagate-old/restic-arch-kingston` — snapshot `38b4b9c3`      |

Pra garimpar sem restaurar tudo, monte o snapshot como pasta navegável:

```bash
sudo restic-arch-kingston-local mount /mnt/arch-antigo   # Ctrl+C desmonta
```

Os dotfiles do Arch ficam em `home/v1cferr/dotfiles` dentro do snapshot. Existe também
uma cópia manual do `Projects` do Arch em `~/BACKUP-KINGSTON/` (14 G) — pode apagar
quando terminar de consultar; o conteúdo está nos repos acima.

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
- [x] Higiene de disco (30/07) — o pedido era "GC automático que não deixe o disco encher", e o
      GC JÁ existia e funcionava (nix.gc weekly + --delete-older-than 30d, auto-optimise-store com
      628.191 hardlinks). Medindo antes de mexer, o pedido se revelou mal-endereçado:
        disco usado 625.7 GiB | /nix/store 58.3 (9.3%) | NÃO-Nix 567.4 (90.7%)
        Bottles 319 GiB (Battlenet 181, Cities-Skylines-II 86, Ascension 47) | Jellyfin 132 |
        Games 47 | Steam 8 | Trash 1.7
      O domínio INTEIRO do GC são 9% do disco: se encher, enche pelos outros 91%, e nenhuma política
      de GC toca em prefixo de Wine. Então, em vez de mais GC:
      • min-free 1→15 GiB (max-free 5→50): coletar só quando sobra 1 GiB é chegar DEPOIS do
        acidente, e a partição é compartilhada com 506 GiB de jogos/mídia — o espaço pode sumir por
        fora do Nix. NOMES conferidos com `nix config show`: neste Nix (2.34.8) valem
        min-free/max-free; o rename p/ gc-threshold/gc-limit + auto-gc é de versão mais nova e NÃO
        existe aqui — seguir a pesquisa às cegas geraria opção inválida.
      • journald ganhou TETO (SystemMaxUse=2G). NÃO havia nenhum, e o default do systemd é 10% do
        filesystem = ~92 GiB nesta máquina, sem nada denunciar. Crescimento de log não é hipótese:
        dois timers MEUS escreviam 2148 linhas/dia até ganharem LogLevelMax.
      • ALARME (home/services/disk-hygiene.nix): timer --user que notifica quando o livre cai,
        JÁ COM os maiores consumidores na mensagem — o pedido era poder AVALIAR o que remover, e p/
        isso a notificação tem de dizer O QUE cresceu. Duas fases de propósito: `df` (instantâneo) a
        cada 30 min, e o `du` (que leva MINUTOS aqui) só quando o disco está baixo, com nice+ionice.
        Anti-spam de 12h por severidade, escalando na hora se warn→crit — notificação repetitiva
        passa a ser ignorada, o mesmo erro do journal afogado.
      • Lixeira expira sozinha aos 30d (trash-cli, `-f` explícito: unit que espera resposta fica
        pendurada). Era o ÚNICO lixo real da medição — 1.7 GiB que o restic já exclui do backup.
      • Ferramentas: já havia gdu (TUI) e filelight (GUI, pastas). Faltavam as outras DUAS
        perguntas: `czkawka` (GUI — duplicatas, arquivos grandes, pastas vazias: o que é
        DESCARTÁVEL, não só o que é grande) e `nix-tree` (qual PACOTE pesa no closure; foi como se
        mediu que o xembedsniproxy custa 429 MiB de qtwebengine).
      NÃO automatizado de propósito: apagar jogo/mídia. Ninguém deve deletar 319 GiB de jogos por
      conta própria — daí alarme em vez de faxina. Achado p/ o dono decidir: existe um bottle
      "Battle.net" de 688 MiB ao lado do "Battlenet" de 181 GiB, com cara de tentativa abandonada.
- [ ] Verificar se é possível adicionar estado declarativo criptografado
- [ ] IMPERMANÊNCIA no Kingston — ideia do dono (30/07), inspirada no
      <https://github.com/Misterio77/Foundry>: raiz efêmera (tmpfs ou subvolume zerado no boot) +
      lista EXPLÍCITA do que persiste. Encaixa em duas coisas que este repo já tem: a regra 6
      (Nix = app+config; estado = restic) deixaria de ser convenção e passaria a ser IMPOSTA pelo
      sistema — o que não está declarado como persistente simplesmente não sobrevive ao boot; e
      responde o item acima (estado declarativo criptografado), porque o par natural é
      impermanência + LUKS.
      PONTOS A DECIDIR ANTES, medidos hoje: os 567 GiB de não-Nix (Bottles 319, Jellyfin 132,
      Games 47) são estado GRANDE e legítimo — impermanência não os apaga, mas obriga a declarar
      cada caminho, e errar a lista significa perder save/prefixo no reboot. Candidatos: módulo
      `impermanence` (nix-community) ou o esquema do Foundry.
      ⚠️ A migração JÁ ACONTECEU (01/08/2026) sem ligar a impermanência, então a premissa
      original ("fazer junto, em instalação nova") caducou: agora é conversão de máquina em
      uso, que era justamente o caminho que eu queria evitar. O layout btrfs salva a maior
      parte do custo — falta o `@-blank` e a lista, não uma reinstalação.
      DECIDIDO em 01/08/2026, ao montar o hosts/nixos-kingston (o LAYOUT já está pronto):
      • btrfs SIM — não por gosto, mas porque /nix e /persist precisam ser volumes separados
        DESDE a instalação; ext4 plano custaria uma segunda reinstalação. Subvolumes criados:
        `@ @home @nix @persist @log @swap`. Confere com o Foundry (raiz = subvolume zerado no
        boot, não tmpfs; tmpfs tetaria a raiz nos 15 GB de RAM).
      • LUKS NÃO — a passphrase no boot mataria o autologin de que o Sunshine depende pra
        acesso remoto depois de queda de energia. É a diferença deliberada pro Foundry.
      • `@home` como subvolume PERMANENTE (o Foundry não tem) — estágio intermediário de
        propósito: liga a impermanência na raiz primeiro, e só depois decide estendê-la ao
        home. NÃO tranca nada: estender é zerar o @home pelo mesmo mecanismo, sem reinstalar.
        É a resposta ao risco dos 567 GiB acima — declarar tudo de primeira é onde se perde.
      • `/var/lib` NÃO é subvolume, e isso é proposital: se fosse permanente, nada obrigaria
        a declarar. Consequência a lembrar: o estado de serviço que o cutover copia pra lá
        (uid-map, NetworkManager, bluetooth…) é ZERADO no reboot quando a feature entrar —
        tem que migrar pro /persist e ser declarado. Esse é o trabalho, não um bug.
      FALTA só: o snapshot `@-blank` (base do rollback) e a lista de persistência. O blank NÃO
      é now-or-never — subvolume vazio criado depois é idêntico a snapshot em branco.
- [x] Clipboard (Wayland) — cliphist DECLARATIVO (services.cliphist, allowImages=texto+imagem)
      + picker no ROFI com PREVIEW: thumbnail das imagens copiadas + ícone por TIPO de arquivo
      (zip/vídeo/pdf/exe… via Fluent-dark), tema Tokyo Night, SUPER+SHIFT+V. Migração melhorada
      do cliphist-rofi-img.sh do Arch (script clipboard-menu). home/desktop/clipboard.nix
      (substituiu o antigo picker wofi-text). + wl-clip-persist (autostart hypr): mantém a
      cópia viva após o app fechar (fix da imagem do Flameshot — dono do clipboard no Wayland).
- [x] Dark mode no file manager (Dolphin) — Qt segue o GTK escuro (home/desktop/theme.nix)
- [x] Cheatsheet de keybinds no rofi (SUPER+H, home/desktop/cheatsheet.nix) — GERADO do
      keybinds.lua em RUNTIME por um awk, nunca escrito à mão: lista duplicada viraria
      mentira no primeiro bind novo. Lê ~/.config/hypr/lua/keybinds.lua, que é
      mkOutOfStoreSymlink pro repo, então acompanha até hot-reload sem rebuild. Grupo = 1ª
      linha do bloco de comentário acima do bind; descrição = comentário no fim da linha,
      com fallback pro texto do grupo. Verificado contra `hyprctl binds`: 91/91 cobertos,
      0 faltando. DOIS BUGS que custaram versões: (a) achar o comentário por regex "sem
      hífen" some com descrições legítimas (no-op, qs-restart) — tem que ser a ÚLTIMA
      ocorrência de " -- "; (b) traduzir tecla com gsub cego troca o "left" DENTRO de
      "mouse_left" — tem que ser token a token. H e não "/" porque o Moonlight não envia
      a "/" do ABNT2 (mesma razão do remap do ScrollLock).
- [x] Layout SCROLLING (fita infinita) em TRIAL nas ws 2 e 6 — pra parar de pular de workspace
      só pra manter poucas janelas na tela. É NATIVO no Hyprland 0.55.4 do nixpkgs: sem plugin,
      sem flake input (o hyprscrolling não entra nessa história). Convive com o dwindle via
      `hl.workspace_rule({ layout = "scrolling" })` (monitors.lua) — general.layout segue
      "dwindle", então dá pra comparar os dois no mesmo dia e reverter apagando 1 palavra.
      Nenhum bloco `hl.config({ scrolling = ... })`: os 7 valores que eu queria (column_width
      0.5 = 2 colunas de 960px em 1080p, fullscreen_on_one_column, focus_fit_method, follow_focus,
      wrap_focus, direction, explicit_column_widths) JÁ SÃO os defaults — conferido com
      `hyprctl getoption`. Binds em keybinds.lua: SUPER+,/. rola a fita por coluna (é o atalho
      de TECLADO, funciona sem mouse), SHIFT+ reordena, ALT+ cicla largura, I/O empilha/desempilha
      na coluna, G recentra e SHIFT+G expande pro espaço livre.
      DUAS PEGADINHAS que o wiki não conta:
      1. `fit_into_view` está DOCUMENTADO no wiki e NÃO EXISTE no 0.55.4 ("no such layoutmsg for
         scrolling"). O equivalente que funciona é `fit active`. Varri as 12 mensagens que os
         binds usam uma por uma com `hyprctl dispatch` — só essa era fantasma.
      2. TODA mensagem de layout exige janela FOCADA: sem foco elas devolvem "no focused window"
         e não fazem nada, silenciosamente. Foi o que me fez achar (errado) que `move ±col`
         estava quebrado — as janelas de teste tinham subido com regra `silent`.
      3. BIND É GLOBAL, MENSAGEM DE LAYOUT NÃO É. Numa ws dwindle o Hyprland responde "Unknown
         dwindle layoutmsg: move +80" e emite UMA NOTIFICAÇÃO POR EVENTO — com o thumbwheel
         disparando em rajada, a tela vira uma parede de toasts. Por isso os binds da fita
         passam por um guard (`fita()` no keybinds.lua) que só despacha se a ws ativa estiver
         em `scrollingWs`. Três becos sem saída até chegar nele: (a) `pcall` NÃO abafa — o
         checkResult (LuaBindingsInternal.cpp:376) emite a notificação e devolve {ok=false}
         sem levantar erro Lua, não há o que capturar; (b) não dá pra perguntar o layout — o
         objeto de workspace expõe id/name/monitor/windows/last_window e `layout` é nil, daí a
         lista de ws ser espelhada À MÃO do monitors.lua; (c) `d()` não executa nada — tem que
         ser `hl.dispatch(d)` ("dispatcher objects cannot be called directly", literal na
         LuaBindingsDispatcherUtils.cpp:24). Custei duas medições achando que o guard estava
         quebrado por causa do (c).
      PROMOVIDO A GLOBAL (jul/2026): o trial nas ws 2 e 6 foi aprovado no uso, então
      `general.layout = "scrolling"` e as 8 ws viram fita. Saiu junto: o `layout=` das
      workspace_rule, o bloco `dwindle` do appearance.lua (nenhuma ws usa mais) e o guard
      do keybinds.lua com a lista espelhada — sem ws dwindle não existe o erro que ele
      evitava, e lista espelhada à mão é dívida. Se ALGUMA ws voltar a ser dwindle, o guard
      é OBRIGATÓRIO de volta (está no commit 7f74ae8). `SUPER+P` (pseudo) virou no-op, mas
      responde `ok` — é dispatcher de janela, não mensagem de layout, então não gera toast.
      EM ABERTO: com `follow_mouse=1` o foco troca sozinho enquanto a fita anda (as janelas
      deslizam sob o cursor parado) e o `follow_focus` recentra, deixando o deslocamento
      irregular — medi foco pulando d→b→a→Zen num teste. `follow_focus=false` NÃO resolveu
      (3 disparos sem mover, depois salto de +1520). Só dá pra julgar no uso real, porque
      disparar por `hyprctl` com cursor parado não reproduz o uso de verdade.
      4. Mover janela DE LADO na mesma ws = `swapcol l/r` (SUPER+SHIFT+,/.), e ele move a
         COLUNA INTEIRA — pilha junto — dando a volta nas pontas. Pra mover só UMA janela de
         uma pilha: `expel` (SUPER+O) primeiro, aí swapcol. NÃO usar o `window.swap({direction})`
         genérico: não é layout-aware e fundiu janelas sem relação numa coluna no teste.
      5. ARRASTAR (SUPER+clique) NUNCA cria coluna — é hardcoded. No CScrollingAlgorithm::
         newTarget, o ramo `wasDraggingWindow() && draggingTiled()` sempre faz
         `droppingColumn->add(target, ...)`, ou seja EMPILHA na coluna de destino; a única
         escolha é acima/abaixo, por o cursor estar acima ou abaixo do meio da janela-alvo.
         O ramo que cria coluna (`add(idx, width)`) é o de janela NOVA, e o arrasto não passa
         por ele. Não há knob: nenhuma das 9 chaves do `scrolling` toca em arrasto. Pra pôr
         lado a lado use SUPER+O (expel) + SUPER+SHIFT+,/. Brecha do mouse: soltar em ÁREA
         VAZIA cai no `if (!droppingColumn)` e cria coluna — mas no FIM da fita, não onde
         soltou. (Este item foi LIDO NA FONTE e não medido: não dá pra sintetizar arrasto.)
      6. TODA forma de mover janela pro lado EMPILHA — testei as três: arrasto (lido na
         fonte), `window.swap({direction})` e `window.move({direction})`. As duas últimas
         medidas: mandam a janela pra DENTRO da coluna vizinha, não pro lado dela. Lado a
         lado só existe no nível de COLUNA (swapcol/expel/colresize/fit). O scrolling é um
         layout 1-D e o mouse é 2-D; é essa a incompatibilidade de fundo.
         RESPOSTA DE MOUSE: (a) SUPER+botão-direito+arrastar redimensiona a coluna e
         encolher revela a vizinha — já existia; (b) SUPER+clique-do-meio = expel + fit all
         num gesto (lambda Lua com hl.dispatch, pois um bind só aceita UM dispatcher):
         desfaz o empilhamento que o arrasto causa e mostra a fita inteira.
- [x] REVISÃO (jul/2026) do thumbwheel + largura, depois de usar: a fita virou 1 JANELA POR
      TELA (`scrolling.column_width = 1.0`, único valor fora do default) e o thumbwheel
      DEIXOU de ser divertido pelo logiops. Agora a rodinha do polegar faz scroll horizontal
      NATIVO dentro dos apps (VS Code, tabela larga), e a fita anda só com SUPER + rodinha,
      por bind em `mouse_left`/`mouse_right`. O que destravou isso: o teto de 300ms do
      `binds:scroll_event_delay` era o motivo de TODO o rodeio via logiops — mas ele só é
      fatal pra rolagem suave em PIXELS. Andando de COLUNA em coluna, com 1 coluna = 1 tela,
      3 disparos/s é de sobra, e aí o custo do divert (matar o scroll horizontal dos apps)
      deixou de se pagar. Binds novos: SUPER+CTRL+./, = `colresize all 1.0`/`0.5`, que mexe
      na fita INTEIRA (o SUPER+ALT+,/. só mexe na coluna ativa). Lição: o teto de 300ms não
      é bom nem ruim em abstrato — ele só importa se o passo for pequeno.
      MODOS DE VISÃO (o complemento do 1.0): `fit all` em SUPER+CTRL+G espreme a fita INTEIRA
      na tela, adaptando à quantidade — 4 janelas viram 4x470px lado a lado; SUPER+CTRL+.
      volta pra 1 por tela. É o "ver tudo de uma vez" pra quando o contexto importa mais
      que o foco. PEGADINHA: `colresize all N` sozinho NÃO traz a vista junto — encolhi 2
      colunas pra 0.5 e AS DUAS ficaram fora da tela, à esquerda; o `fit all` redimensiona
      E reposiciona. Alternativa por-app (testada, funciona): window_rule com
      `scrolling_width = 0.5` faz um app específico já nascer com meia tela.
- [x] [HISTÓRICO — revertido acima] Thumbwheel do MX Master rola a fita — mouse.nix ganhou um
      bloco `thumbwheel` que DIVERTE a roda e sintetiza SUPER+CTRL+,/. (keybinds.lua move ±80px).
      Por que keypress e não bindar `mouse_left`/`mouse_right` (que o Hyprland suporta
      nativamente): `binds:scroll_event_delay` = 300ms é um TETO de ~3 disparos/s pra bind de
      roda, o que travaria a rolagem; e baixar o teto estragaria o SUPER+roda-vertical de
      workspace, que tem hi-res scroll ligado. Keypress não passa por esse teto.
      Por que 80px e não 1 coluna: no thumbwheel o logiops IGNORA o `interval` depois do 1º
      disparo e manda um evento por incremento mínimo (issue #310, ABERTA) — em vez de brigar,
      o desenho assume rajada, e rajada de passo pequeno = rolagem suave. Calibrar a velocidade
      no `move ±N` do keybinds.lua (hot-reload), NUNCA no `interval` (rebuild e sem efeito).
      Por que combo de 3 teclas e não F13/F14 por keycode: `hl.bind("code:191", ...)` registra
      com `keycode=0` no `hyprctl binds` e não deu pra provar que dispara (não consigo apertar
      F13); comma/period registram certo, e sintetizar combo já é padrão provado aqui (o botão
      de gestos faz isso desde sempre). Se um dia o combo se mostrar instável em rajada, F13
      via `code:191` é o plano B (evdev 183 + 8 = xkb 191; o +8 está no KeybindManager.cpp:338).
      CUSTO ACEITO: `divert` mata o scroll horizontal DENTRO dos apps (VS Code, tabela larga no
      browser, Dolphin). Se incomodar, `divert = false` devolve — e aí o bind vira SUPER+roda.
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
  - [x] FIX (jul/2026) do "?" que nunca saía — `send_shortcut: key not found`. O bind usava
        `key = "slash"`, e o resolveKeycode do send_shortcut varre o keymap com
        `xkb_state_key_get_one_sym` (LuaBindingsDispatchers.cpp), que respeita os modificadores
        APERTADOS NA HORA — ou seja, só acha keysym do nível ATIVO. No bind do "?" o Shift está
        segurado → o nível 2 está ativo → nenhum keycode produz `slash` (produzem `question`) →
        erro. Prova: `key = "question"` SEM shift falha igual, espelhado. AGRAVANTE: o
        m_keyToCodeCache só é populado em caso de SUCESSO, então um "/" bem-sucedido antes
        deixava o "?" funcionar por cache — o bug só aparecia com cache frio (ex.: depois de um
        `hyprctl reload`), o que fazia parecer intermitente. FIX: `key = "code:97"`, que faz
        short-circuit ANTES de tocar no estado xkb → imune a modificador e a cache. 97 = `<AB11>`,
        a tecla "/ ?" do ABNT2 (evdev KEY_RO 89 + 8), conferido com
        `xkbcli compile-keymap --layout br --variant abnt2`. LIÇÃO: em send_shortcut/send_key_state
        com modificador, usar SEMPRE `code:` — keysym só é confiável em bind sem modificador.
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
- [ ] Configurar o WoW Ascension com o Bottles para jogarmos, e ir configurando o
      sistema simultaneamente. (Escrito como "depois que eu estiver no SSD" — o cutover
      já aconteceu em 01/08 e o daily driver é o NVMe Kingston, então isso está livre.)
- [ ] **Dissipador M.2 para o KC3000** — medido em 01/08/2026: 77–80 °C sob carga, e o
      contador de gestão térmica SOBE durante I/O pesado (`T1 Trans Count` foi de 17 pra
      18 num único benchmark; 24.781 s acumulados). Nunca cruzou o limiar de aviso do
      controlador e o disco está impecável (`media_errors: 0`, spare 100%, 4% de vida
      usada, leitura 6911 MB/s = 98,7% do catálogo), mas a Kingston especifica operação
      até **70 °C** e agora ele é o daily driver, não mais o disco secundário parado.
      Conferir primeiro se a placa tem dissipador no slot e como é o fluxo de ar perto
      da Arc B580. Preferir PASSIVO: ventoinha de 30 mm alimentada por Molex roda em
      rotação fixa, chia, não tem tacômetro e morre em 1–2 anos — e ventoinha morta
      dentro de carcaça fechada é pior que dissipador passivo. Medir depois com
      `sudo nvme smart-log /dev/nvme0n1 | grep -E "^temperature|Sensor 2|T1 Trans"`.

- [x] Verificar a arquitetura de pastas e melhores práticas para manutenção/organização/
      escalabilidade — FEITO. Reorganizado por categoria (padrão da comunidade):
      home/ → shell/ desktop/ apps/ services/ + packages.nix (lista central de apps
      de usuário); system/ → core/ hardware/ net/ desktop/ services/ + packages.nix.
      Cada subpasta tem seu default.nix. README atualizado.
- [x] Remover todos os outros hosts e manter apenas o atual. (Hoje o ativo é o
      hosts/nixos-kingston/; o nixos-sandisk sobrou como molde — o disco dele é o Windows.)
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
- [x] Adicionar um método de zip direto no tooltip do meu file manager (Dolphin) — zipar sem abrir o terminal, via menu de contexto (botão direito). FEITO: kdePackages.ark (servicemenus "Comprimir/Extrair" no botão-direito). home/apps/dolphin.nix.
- [x] Adicionar um arquivo para declarar quais softwares inicializam e ficam ativos com a minha
      maquina (ligar/desligar) — FEITO: PAINEL central `system/services/toggles.nix` (`my.services.<n>`,
      mkEnableOption + mkIf/enable-gate, padrão idiomático). Flip true/false + `rebuild` liga/desliga
      10 opcionais (jellyfin, ollama, duo, sunshine, qbittorrent, restic, cloudflare-ddns, dropbox,
      discord-rpc, cs2-backup). Essenciais (tailscale/mouse/desktop/keyring/earlyoom) e VPN (sob-demanda) FORA.
- [x] PAINEL de autostart (30/07) — `my.autostart` em home/desktop/autostart.nix: o que ABRE
      junto com a sessão, no idioma do toggles.nix. Discord e Spotify entraram como SERVIÇO
      --user, não `exec-once`, porque exec-once NÃO reinicia se o app morrer — era o que faltava
      p/ "continue ativo". `Restart=on-failure` de propósito: crash volta, fechar na mão respeita
      (com `always` seria impossível fechar).
      CORREÇÃO (30/07) — a justificativa acima vinha com "(Electron sai com 0 ao fechar)", que era
      FALSO p/ o Spotify: ele é CEF, e o `bin/spotify` MOVE o processo real p/ um scope próprio
      (`app-org.chromium.Chromium-<pid>.scope`, fora do cgroup da unit), com o processo acompanhado
      pelo systemd SAINDO COM 1 mesmo quando a app subiu bem. Resultado: on-failure reiniciava a
      cada 5s, o novo launcher achava a instância viva, imprimia "Opening in existing browser
      session" e MANDAVA A JANELA APARECER. Medido no journal: 4145 reinícios num dia. Fix em duas
      camadas: `successExit=1` no Spotify (sair 1 é o caminho normal dele; a unit é LANÇADOR, não
      supervisor — escapando do cgroup o systemd já não supervisionava nada) + StartLimit de
      3/5min em TODAS as units do painel. A causa do estrago não foi só o código de saída: era não
      haver limite — com RestartSec=5 dava 2 partidas/10s, sempre sob o burst=5 default, então o
      freio de fábrica NUNCA atuava. O comentário é que segurou o bug de pé: ele explicava a
      escolha errada de forma convincente. O header é ÍNDICE dos TRÊS lugares que sobem coisa
      no boot (este painel, my.services, e o exec-once do autostart.lua p/ hyprlock/qs/clipboard)
      em vez de fingir centralização total — o hyprlock no exec-once é load-bearing p/ acesso
      remoto. `spotify --minimized` existe mas o --help diz "Only works on Windows": p/ não roubar
      foco no login o caminho é window rule (`workspace N silent`), não flag de app.
- [x] Aliases de print migrados do Arch (30/07) — screenshot/scfull/sc1/sc2 em
      home/apps/flameshot.nix (junto da ferramenta, como o eza/bat no cli.nix; o zsh.nix guarda
      só os de shell/sistema). TESTADO no v14/Wayland antes de portar: só o `gui` abre o picker de
      monitor; `full` e `screen --number` capturam direto. `--number` é índice do Qt, não nome de
      monitor, então NÃO sai do my.monitors — medido capturando as duas telas e comparando com os
      wallpapers: 0 = principal, 1 = TV. REMEDIR se o layout de monitores mudar.
- [ ] Instalar o driver/software do meu mouse Razer Deathadder v2 (adicionar a notificação de quando meu DPI mudar, etc)
- [x] Configurar meu launcher de apps (colocar icones, filtro pelos ultimos utilizados e etc)
      — FEITO: rofi `drun` (ícones Fluent-dark + fuzzy + histórico/recência) tematizado pela
      paleta única (my.theme), UI en-US. SUPER+Q (apps) / SUPER+R (bins). Saiu do wofi →
      consolidado no rofi (mesmo tool do clipboard). home/desktop/launcher.nix.
- [x] Clipboard manager com visualização de imagens/arquivos + histórico — FEITO com rofi
      (não quickshell): cliphist + rofi c/ preview (thumbnail + ícone por tipo). Ver acima.
- [x] Clicar no ws-pill p/ trocar de workspace (Bar.qml) — ficou QUEBRADO da migração p/ o
      Hyprland 0.55 até 30/07, marcado aqui como feito com o comando errado. O `dispatch` virou
      atalho p/ `hl.dispatch(...)`, então a forma antiga montava `hl.dispatch(workspace 3)` e
      estourava no parser Lua. O clique morria em SILÊNCIO porque o `execDetached` do Quickshell
      não mostra stderr. Forma correta: `hl.dsp.focus({ workspace = N })` — e cuidado, o óbvio
      `hl.dsp.workspace(N)` falha com "attempt to call a table value", porque ali é TABELA
      (só sub-dispatchers). Delegate de Repeater não pega no hot-reload: pede SUPER+ESCAPE.
      TERCEIRO item marcado [x] sem funcionar (com o wallpaper e o screenDP1) — ver regra 14.
- [~] Tray: CLIQUE já funcionava (30/07) — o delegate do Bar.qml tem esquerda `activate()`,
      meio `secondaryActivate()`, direita abrindo o menu SNI nativo (TrayMenu) e roda com
      `scroll()`. O item estava marcado como pendente estando pronto — inverso do padrão do
      wallpaper/screenDP1/ws-pill, e igualmente enganoso.
      O que ESTAVA quebrado ali era outro: o fallback de clique-direito p/ SNI sem DBusMenu
      (xembedsniproxy: wine/Battle.net, pamac) chamava
      `$HOME/.config/waybar/scripts/tray-native-menu.sh` — caminho da WAYBAR, que foi
      removida na migração; o dir não existe e o script não estava no repo. Portado do legado
      p/ writeShellApplication (regra 7) e chamado por NOME pelo PATH.
      HOVER NO MENU (30/07) — o menu do tray abria e NÃO recebia UM evento de ponteiro: nenhum
      hover, e fechava aos 4s com o mouse parado em cima. NÃO era cor nem QML: hyprwm/Hyprland#6682,
      popup Qt REDIMENSIONADO depois de exibido fica com a região de input errada. Encaixa exato — o
      openAt() torna a janela visível ANTES de o QsMenuOpener popular os itens, então o card nasce
      pequeno e cresce. Reproduzido com o PRÓPRIO Quickshell, FECHADO como "not planned". FIX:
      PopupWindow → PanelWindow (layer surface), que não passa por xdg_surface::set_window_geometry.
      Estava na cara: era o ÚNICO PopupWindow do shell — os outros 4 painéis são PanelWindow e todos
      tinham hover. De quebra cobre a abertura de SUBMENU, que também cresce depois de exibida.
      Preço: posicionar à mão (sem anchor.rect/PopupAdjustment.Slide) — X vem do ícone + clamp.
      MEDIÇÃO que fechou o caso: amostrando `hyprctl layers` a 0.4s (o menu agora É layer, então
      APARECE ali — observabilidade que o popup não dava), uma janela ficou 7.46s de pé, acima do
      timer de 4s → o HoverHandler enxerga o cursor. Antes TODA janela morria em ~3.7s.
      HOVER VISÍVEL — o realce existia e era INVISÍVEL: `border`@20% sobre o fundo do menu dá
      1.11:1 de contraste (medido). Trocado por `accent`@30% = 1.77:1 E mudança de MATIZ
      (cinza→azul), que é o que a vista pega. Tokens colMenuHoverBg{,Danger} no Theme, + barra de
      acento de 3px deslizando pela esquerda (fundo = sinal de ÁREA, barra = sinal de POSIÇÃO).
      A medição também desmentiu uma escolha minha: eu fiz o texto acender em accent, que sobre o
      fundo aceso cai a 3.83:1 contra 5.97:1 do colText — piorava a legibilidade por efeito.
      PONTE XEmbed→SNI (30/07) — os comentários deste repo citavam o `xembedsniproxy` em 3 lugares
      como se ele existisse, e ele NUNCA ESTEVE INSTALADO: o tray-native-menu era código morto,
      porque nenhum ícone sem DBusMenu chegava a existir. App X11 legado (Wine/Bottles → Battle.net)
      publica ícone por XEmbed, não SNI; sem host XEmbed o Wine desenha a bandeja numa JANELINHA
      própria (medida: class=explorer.exe, 160x20, flutuando). Agora o proxy é declarado
      (home/desktop/quickshell.nix). Causalidade demonstrada nos DOIS sentidos: proxy de pé = 4
      itens no watcher e explorer.exe=0; proxy morto = 3 itens e a janelinha volta. CUSTO medido e
      assumido: 758 MiB novos no closure (429 deles qtwebengine, + kwin/breeze/oxygen), porque o
      binário só existe no kdePackages.plasma-workspace. Alternativas descartadas com motivo:
      `snixembed` faz o caminho INVERSO (publica SNI como XEmbed) e por isso tenta ser o watcher,
      morrendo com "could not acquire watcher name" (o Quickshell já é); não há standalone no
      nixpkgs; extrair o binário não escapa (plasma-workspace referencia kwin/breeze/oxygen
      DIRETO); stalonetray = janela flutuante de novo.
      LIMITAÇÃO do ícone que vem pela ponte, medida: sem nome e sem menu — `Id` é o window ID do X11
      em decimal ("14680083"), `Title`/`ToolTip` vazios, `Menu` inexistente. O clique-direito cai no
      tray-native-menu (que só AGORA tem uso real) e o tooltip pendente não pode se contentar com o
      `Id`: p/ estes teria de resolver o WM_CLASS.
      ÍCONE FANTASMA (30/07) — fechar o Battle.net deixava o ícone na barra, sem responder a clique
      nenhum. NÃO era bug do proxy: o `battle.net.exe` sai sem remover a registração e o
      `explorer.exe` do Wine segue segurando a janela (xprop: WM_CLASS=explorer.exe,
      _NET_WM_PID vivo). Do lado do X a janela existe; do lado do app não há quem responda. O
      helper funciona — `tray-native-menu <id>` retorna exit=0, achou o item e chamou ContextMenu().
      Conserto: `wineserver -k` no prefixo do Bottles (NÃO reboot); o proxy então LIMPA o item
      corretamente (4→3 itens, janela 0, unit intacta). Se um dia sobrar item com a janela já morta,
      `systemctl --user restart xembedsniproxy`.
      FALTA: o TOOLTIP, que não existe em nenhum lugar da barra. O SNI do Quickshell expõe
      `tooltipTitle`/`tooltipDescription` prontos; o padrão a seguir são os popovers
      (PanelWindow ancorado, ver MetricsPopover.qml). MEDIDO nos itens de hoje: o Discord publica
      ToolTip com título "Discord", o Sunshine deixa VAZIO e só tem Title="sunshine", e o ícone da
      ponte XEmbed não tem nem um nem outro → a cascata precisa ser tooltipTitle → title → id, e
      p/ os da ponte, WM_CLASS.
      NOTA DE MEDIÇÃO: contei itens de tray com `busctl --user list | grep StatusNotifierItem`
      e deu 0, o que é FALSO — app que registra com nome único (`:1.82`) não casa esse padrão.
      A fonte autoritativa é a propriedade `RegisteredStatusNotifierItems` do watcher (é o que
      o tray-native-menu lê): 3 itens.
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
- [x] Flameshot vs. barra: "barra duplicada" no print (30/07) — o overlay do flameshot é
      JANELA normal, e no Hyprland janela NUNCA cobre layer `top`, onde a barra vive
      (`hyprctl layers` → "Layer level 2 (top): namespace: quickshell"). O overlay mostra um
      frame CONGELADO que já contém a barra, e a barra VIVA desenha em cima → duas barras.
      Não há window rule que inverta: é feature request ABERTA (hyprwm/Hyprland#4847), e a
      comunidade confirma que nem a layer `overlay` cobre um bar em `top`. FIX declarativo:
      `IpcHandler` no Bar.qml (hide/unhide) + o flameshot-screenshot chamando em volta do
      loop que ele já tinha. ORDEM IMPORTA: esconde DEPOIS que a janela aparece, quando o
      frame já foi capturado → a barra CONTINUA no print, só a duplicata viva sai.
      `visible: false` desmapeia a layer, o que também libera o strip de 30px p/ selecionar
      região no topo. PEGADINHA: a função IPC não pode se chamar `show` — colide com o
      subcomando `qs ipc show` e o CLI nunca a chama (já documentado no IpcHandler do vpn).
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
      hi-res scroll, botão de gestos → GERÊNCIA DA FITA (era workspaces; mudou quando o
      scrolling virou global e workspace deixou de ser onde se estoca janela): ← / → movem
      a janela pela fita (swapcol), ↑ = ver tudo, ↓ = foco 1-por-tela, clique = launcher.
      Cada gesto sintetiza um bind que JÁ EXISTE no keybinds.lua — nunca uma ação exclusiva
      do mouse, senão o cheatsheet do SUPER+H (que é gerado do keybinds.lua) não a veria.
      MOUSE E FITA, o resumo: arrastar NUNCA cria coluna (empilha, hardcoded); quem põe uma
      janela do lado da outra com o mouse é SUPER+botão-direito+arrastar, que redimensiona a
      coluna — o scrolling implementa resize-drag de verdade (borda esquerda mantém a direita
      parada ajustando a câmera; borda direita mantém a esquerda fixa), e encolher revela a
      vizinha. Isso já existia desde sempre no keybinds.lua e eu não sabia. PEGADINHA BT: boot-race + "5 tries" do HID++ →
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
- [ ] Adicionar a parte para entrar via SSH sem senha no meu roteador (OpenWRT) e no meu switch (OpenWRT) para poder fazer manutenção remota
      sem precisar digitar senha
- [x] Verificar se a conexão com o moonlight está estável (monitorar e ter logs) — FEITO
      (31/07), e a MEDIÇÃO derrubou quatro hipóteses minhas antes de sobrar uma. Ferramenta
      `moonlight-stats [dias]` (system/services/sunshine.nix): lista as sessões e cruza cada
      uma com os eventos do tailscaled no MESMO intervalo.
      O ACHADO que orienta tudo: a distribuição é BIMODAL — ou a sessão dura HORAS, ou morre
      em 3-60 s. Em 7 dias: 67 sessões, mediana 40 s, 39 delas abaixo de 120 s, e a maior com
      12155 s. Não é rede "degradando aos poucos"; são dois regimes distintos.
      REFUTADAS, cada uma pelo mesmo teste (se as sessões LONGAS sofrem MAIS o evento, ele é
      sobrevivível e não é a causa) — e a taxa tem de ser POR MINUTO, senão sessão de 3 s
      "nunca" tem evento só por ser curta, viés que quase fechou o caso errado:
        • flapping de caminho IPv4↔IPv6 do Tailscale: só 1/39 curtas teve UMA troca, e uma
          sessão de 74 min sobreviveu a 40 trocas.
        • saturação de upload: a casa tem 347 Mbps de subida (medido), 0% de perda em ping
          ocioso, 23 ms de RTT.
        • link change/rebind do tailscaled (302 e 449 em 7 dias, que davam MUITA cara de
          culpado): 0/39 curtas tiveram algum, e a sessão de 4455 s aguentou 76 link changes
          + 114 rebinds.
        • blackhole da VPN FAI: a hipótese era boa (o cliente está em 200.136.193.228, a FAI,
          e o split-tunnel do nxBender filtra só o /0 → as sub-redes da FAI ENTRAM no ppp0,
          o que capturaria a rota do endpoint do cliente). Refutada: as longas têm MAIS ppp0
          de pé (mediana 62% do tempo) que as curtas (0%), e a de 8495 s rodou com o túnel
          ativo 100% do tempo.
      O que SOBROU, e é onde o host não vê nada: durante TODA sessão curta o log do Sunshine
      está limpo — sem erro de encoder, de captura ou de rede. Some com o cliente. A única
      correlação que resistiu foi o BITRATE PEDIDO: 79 Mbps → mediana de vida 22 s; 23.8 Mbps
      → 290 s. E o `max_bitrate` default é 0 = "obedece o cliente", que é como 79 Mbps entrou.
      Daí o teto de 10 Mbps + FEC 30% + ping_timeout 20 s.
      REVISÃO DESSA ÚLTIMA HIPÓTESE (31/07, medindo p/ responder "10 Mbps serve p/ jogar?") —
      ela ficou MAIS FRACA, e duas premissas caíram:
        • O encoder em uso é AV1 (av1_vaapi, confirmado na instância VIVA), não h264 como
          estava escrito. AV1 rende ~40-50% mais por bit, então 10 Mbps já valiam ~18-20 de
          h264: o teto era mais folgado do que se pensava, por engano e não por escolha.
        • O "cliente pedia 79 Mbps" NÃO vale p/ esta semana. Cruzando `Streaming bitrate is`
          com o encoder ativo no journal, as 7 dias rodaram a 19.4 Mbps — e as CURTAS de
          31/07 (15 a 68 s) TAMBÉM foram a 19.4. Ou seja: queda curta acontece em bitrate
          MODERADO, então o bitrate não é o que a evita. O 79 deve ser de período anterior.
        • A amostra a 10 Mbps era UMA sessão, que nem fechou — aquele teto nunca chegou a ter
          registro de estabilidade, não havia A/B a preservar. Por isso 10 → 20 Mbps.
      CONFUNDIDOR que agora salta: as curtas se concentram na janela das 08h, EXATAMENTE a
      janela em que a rede da FAI derrubou a VPN 52x na semana (ver o item da VPN). Reforça
      "rede da FAI" — que segue suspeita, não fato, pela mesma razão de antes: falta o lado
      do cliente.
      BITRATE POR USO (o que decide é quantos pixels MUDAM por frame, não a velocidade da
      ação): desktop remoto e Hearthstone (câmera fixa) cabem em 10; Cities Skylines II pede
      20-25 porque PAN DE CÂMERA muda todo pixel do quadro — pior caso de compressão
      interframe, apesar de o jogo ser "calmo"; FPS 30+, e aí o gargalo vira latência.
      PMTU CONFERIDA e descartada como causa: `ping -M do` passa até 1280 B cheios até o
      cliente, então o `packet_size=1024` está corretamente dimensionado (era a causa de
      29/07, não é mais esta). Sob rajada o caminho mostra 1.67% de perda e RTT de 20→312 ms
      — indício de rede da FAI ruim, NÃO prova: é ICMP, que firewall desprioriza.
      PESQUISA: a doc oficial do Sunshine só tem "Packet loss → baixe o MTU" (PR #2514), que
      é o que o packet_size já faz; a tailscale/tailscale#14208 relata exatamente esta dor
      (moonlight+ssh caindo, "logs só dizem client disconnected") e segue SEM causa-raiz.
      FALTA a metade que o host não consegue medir — o lado do cliente: overlay de
      estatísticas do Moonlight (Ctrl+Alt+Shift+S) durante uma queda, e iperf3 -u do Windows
      p/ medir o que o fluxo de vídeo sofre (o ICMP acima não serve). Sem isso, "rede da FAI"
      continua sendo a suspeita mais forte e não um fato.
- [x] VPN na topbar (30/07) — o clique no pill abria `vpn menu`: um rofi SOLTO no meio da tela,
      fora do tema do shell. Agora é um popover ANCORADO sob o pill (quickshell/bar/VpnPopover.qml),
      no padrão dos outros painéis: uma linha por VPN com bolinha de estado + botão que alterna
      Conectar/Desconectar, e "Desconectar tudo" no pé. CLIQUE e não hover (há botões dentro;
      painel que abre no hover fecha na primeira distração — mesma escolha do PowerMenu).
      Não é só estética: o rofi montava os rótulos com `systemctl is-active`, que MENTE (o próprio
      vpn.nix documenta em fai_conn/ufscar_conn — no crash-loop do nxBender o systemd diz "active"
      ~2min sem existir ppp0), então ele oferecia "Desconectar" numa VPN desconectada. O popover lê
      o MESMO `vpn status-json` do pill, que checa o TÚNEL. Subcomando `menu` e a dep de rofi
      removidos do CLI.
      E APAGOU ~190 LINHAS DE CÓDIGO MORTO: o shell.qml carregava um painel de VPN inteiro que não
      podia funcionar, por 3 motivos independentes — (1) chamava `$HOME/.local/bin/vpn`, caminho do
      ARCH, verificado inexistente aqui; (2) era INALCANÇÁVEL, único gatilho era `qs ipc call vpn
      toggle`, do módulo custom/vpn da WAYBAR removida; (3) modelava netExtender + perfis do
      NetworkManager e lia um campo `neservice` que o status-json não emite mais. Dos três casos do
      dia dessa família (com o "Electron sai com 0" e o xembedsniproxy), foi o pior: nos outros dava
      p/ não notar, esse NUNCA rodou uma vez.
  - [x] Alerta de falha de conexão (31/07) — falhar era SILENCIOSO: clicava Conectar, nada
        acontecia, e do lado de cá parecia problema da máquina pessoal. `vpn diagnose <id>` +
        `vpn watch <id>` (unit `vpn-watch@`, disparada por fai_up/ufscar_up): 45s depois do
        pedido, se não houver túnel, NOTIFICA dizendo DE QUEM É A CULPA — é essa a informação
        que muda o que se faz em seguida (esperar a FAI vs. mexer na rede/senha).
        NÃO dá p/ usar `OnFailure=` do systemd: com Restart=always + startLimitIntervalSec=0
        estas units NUNCA entram em `failed`, ficam em crash-loop eterno. O gatilho é tempo.
        Classificação por assinaturas MEDIDAS no journal (2 dias), não inventadas:
        ConnectTimeout em /cgi-bin/userLogin (portal fora) = 152 ocorrências, o caso comum;
        "Connection reset by peer" (27); "Modem hangup"/"Peer not responding"/"No response to
        N echo-requests" (túnel subiu e caiu). ORDEM importa: internet daqui -> portal -> log,
        senão um "timeout" no log viraria culpa da FAI com a rede local caída.
        TESTADO contra a falha REAL (a FAI estava fora): veredito "PORTAL DA VPN FORA DO AR —
        não é a sua máquina". E o 1º teste pegou um defeito meu: unidade PARADA era
        classificada como "ainda tentando" com log de DIAS atrás — agora há gate de
        is-active + janela de 15 min na evidência, senão o diagnóstico mente.
        PEGADINHA DO BUILD: backtick dentro de `printf '...'` = SC2016 e o build FALHA; e a
        mensagem sai ILEGÍVEL porque o shellcheck crasha ao imprimir linha com acento
        ("cannot encode character '\227'") — o sandbox não tem locale UTF-8.
  - [x] HANG do nxBender: a VPN que não voltava sozinha (31/07) — CAUSA RAIZ achada num
        diagnóstico guiado. O portal do SonicWall aceita o TCP, o login PASSA
        ("Logging in…" → "Starting session…") e então ele para de responder. O nxBender
        chama o portal SEM timeout (traceback: "connect timeout=None"), então o processo
        dorme p/ SEMPRE: a unit fica `active/running`, ZERO linhas de log, sem túnel — e o
        `Restart=always` JAMAIS atua, porque só reage a processo que SAI.
        EVIDÊNCIA medida: 11 min pendurado com a conexão em ESTAB e Recv-Q/Send-Q ZERADOS
        (`ss -tn state all dst 200.133.233.101`); `systemctl restart` conectou em 10s
        (ppp0 = 192.168.50.6, rotas split-tunnel, workstation:22 aberta, mount rclone OK).
        É a MESMA FORMA do hang do handler HTTPS do Sunshine: ativo, exit 0, invisível.
        FIX: `vpn heal` + timer vpn-heal (2min) — reinicia só quando as TRÊS valem: unidade
        ativa (alguém pediu), túnel ausente, e ativa há mais que a FOLGA de 180s. A folga é
        o que impede o watchdog de matar uma conexão em curso (conectar leva 10-30s) e virar
        o próprio problema. Testado: com a VPN saudável o heal é no-op e o MainPID NÃO muda.
        TRIAGEM que separou "minha máquina" de "a FAI" — vale repetir na próxima:
          `ip route get <ip>`            -> rota normal, sem resto de ppp/tun
          ip rule + ip route table 52  -> Tailscale NÃO cobre os IPs da FAI
          `ping <portal>`                -> 3/3, 31ms: host VIVO
          TCP por porta (python)       -> 4433 ABERTA; 443/80/22 REFUSED (só a 4433 escuta)
          controle UFSCar              -> `www.ufscar.br` e acessoremoto OK = internet sã
        PEGADINHA DE MEDIÇÃO: `ss -tnp` sem root NÃO mapeia PID de processo de outro
        usuário — o "nenhuma conexão" que eu vi era artefato; sem `-p` a conexão apareceu.
