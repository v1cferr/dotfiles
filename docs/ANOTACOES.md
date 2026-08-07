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

Encerrado em 05/08/2026. O Kingston foi formatado (01/08), o módulo que criava os backups
foi apagado, a cópia manual `~/BACKUP-KINGSTON` foi apagada e a perna local (Seagate) saiu
— ficou **só a cópia offsite**, que passou no `check --read-data` (189 packs, 0 erros).

Sobra este ponteiro porque repo que ninguém sabe abrir é pior que repo apagado:

A pasta no Drive foi renomeada `KINGSTON` → **`ARCH-KINGSTON`** em 05/08/2026 (o nome
antigo não dizia que era o Arch). Navegar como pasta, no Dolphin:

```bash
arch-browse                     # monta em /mnt/arch-antigo (Ctrl+C desmonta)
```

⚠️ Desligue a **visualização** (miniaturas) no Dolphin antes de navegar aqui: preview lê o
CONTEÚDO, e cada leitura faz o restic baixar packs do Drive. Medido: uma pasta de 3,9 MiB
custou 3,68 MiB de download só em ícone (ver TODO de 07/08/2026).

O alias está em `home/shell/zsh.nix` e roda SEM sudo de propósito: mount FUSE é privado
de quem montou, então `sudo restic mount` gera pasta que o file manager não abre. Os
dotfiles do Arch estão em `home/v1cferr/dotfiles` dentro do snapshot (`6d7e3ee7`, 44,6
GiB). Os dois segredos seguem declarados de propósito — são a CHAVE do acervo, não sobra
do módulo.

- Repo no GitHub: <https://github.com/v1cferr/dotfiles>

## Ideias

> Quickshell: DECIDIDO — migrei tudo pro Quickshell (ver TODO). Personalizável em QML
> com hot-reload; o Hyprland também virou hot-reload (hyprland.lua via mkOutOfStoreSymlink).
> Para me inspirar: <https://github.com/Misterio77/Foundry>
> Wallpapers Nix: <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>
> Temas centralizados: `home/desktop/palette.nix` (`my.theme`). O nix-colors foi descartado (arquivado + base16 limita a 16 cores).

## TODO

- [x] `arch-browse` voltou a abrir (07/08/2026) — o alias estava CERTO; quem quebrava era o
      backup. `restic-backups-home-gdrive` roda como ROOT e a opção `rcloneConfigFile` só faz
      `RCLONE_CONFIG=/run/secrets/rclone_gdrive_conf`. O rclone renova o token OAuth e
      PERSISTE por cima do arquivo apontado — como root, funciona, e o arquivo recriado nasce
      `root:users`, apagando o `owner = "v1cferr"` do sops. Aí o alias, que roda como usuário
      (mount FUSE é privado de quem monta), não lia mais o rclone.conf.
      • Sintoma traiçoeiro: CONSERTA no reboot (sops reaplica) e quebra no primeiro backup. A
        linha do tempo do dia fechou exata — boot 07:29:47 → `~/Drive` leu OK 07:30:10 → o run
        atrasado das 03:00 (`Persistent = true`) rodou 07:54:39 → segredo virou root 07:54:40.
      • Como foi achado: comparar `/run/secrets/*` com o `manifest.json` do sops do
        `/run/current-system/activate`. Só o `rclone_gdrive_conf` divergia. Vale como receita —
        drift de segredo não aparece em `nixos-rebuild`, só no runtime.
      • Fix: cópia gravável em `/run/restic-backups-home-gdrive/rclone.conf` (o
        `RuntimeDirectory` que o módulo já declara), mesmo padrão do `~/Drive`. O restic nunca
        mais toca no segredo. `mkBefore` no `preStart`, NÃO `mkAfter`: o `initialize = true`
        injeta `restic cat config || restic init` no começo do MESMO script e esse já fala com
        o Drive — copiar depois dele mataria o serviço na largada.
      • Não houve perda de token: `/run` é tmpfs, então a escrita do root já era descartada em
        todo reboot. O sops sempre foi a fonte da verdade.

- [x] Dolphin mais perto do **Windows Explorer** (07/08/2026) — 6 chaves, e só as em que o
      default do Dolphin DIVERGE do Explorer. Cada default foi lido no `config.kcfg` do pacote,
      não chutado; `HighlightEntireRow` e `SortFoldersFirst` já vinham certos e ficaram fora.
      • `[DetailsMode] ExpandableFolders=false` — os `▶` e as linhas de árvore eram a coisa
        mais destoante: o Explorer não tem expansor nessa visão.
      • `[General] ShowSelectionToggle=false` (no Win11 "caixas de seleção" vem desligado),
        `AlwaysShowTabBar=true`, `ShowFullPath=true`, `ShowStatusBar=FullWidth`.
      • `[KDE] SingleClick=false` (duplo clique). ÚNICO item que escapa do Dolphin: é
        kdeglobals, vale pra todo app KDE.
      • O guia "pixel-perfect" que circula (vrunox-9714/dolphin-win11-theme) foi RECUSADO, e
        não por preguiça: depende de regra do **KWin** pra sumir com a barra de título (aqui é
        Hyprland, não há KWin) e de um QSS via `--stylesheet`, que brigaria com o Kvantum que
        já desenha todo o Qt. Antes de copiar receita de tema, checar se ela pressupõe Plasma.
      • FALTA pra fechar o visual: a toolbar (o "command strip" do Explorer). É `dolphinui.rc`,
        XML que o Dolphin reescreve no "Configurar barras de ferramentas" → cai na regra 14, um
        symlink do HM ali brigaria. Se for fazer, é activation idempotente, não `home.file`.

- [x] Ícones do Dolphin: Fluent → **Win11** (07/08/2026) — o pedido era "o mais semelhante ao
      Windows 11 possível", e o ponto de partida já ERA um tema Windows 11 (`fluent-icon-theme`
      é o Fluent Design). Então não foi conserto, foi fidelidade: o `Win11-icon-theme` redesenha
      os ícones da Microsoft, enquanto o Fluent é interpretação autoral do Fluent Design.
      • Decidido OLHANDO, não lendo: montei uma comparação com os ícones reais dos 3 candidatos
        (Fluent / Win11 / We10X), 19 nomes cada, mesmo tamanho e fundo. `We10X` cai fora por
        ser Windows **10X**, geração anterior — aparece nas listas por ser popular, não fiel.
      • Argumento que decidiu: `Win11-icon-theme` é do MESMO autor (yeyushengfan258) do
        `Win11OS-kde` que já vendorizamos pro Kvantum → widget e ícone combinam de fábrica.
      • Preço: sai do nixpkgs (vendorizado, pinado por commit `a5b460a`) → bump virou MANUAL.
      • Três armadilhas pagas no build, todas invisíveis na doc do upstream:
        1. `nativeBuildInputs = [ gtk3 ]` é OBRIGATÓRIO. O install.sh chama
           `gtk-update-icon-cache` no fim de CADA variante e o `set -eo pipefail` mata ali —
           depois de instalar a 1ª. Sem isso o `Win11-dark`, que é o que usamos, nem existia.
           E não é pelo cache: nenhum `icon-theme.cache` sobra no output.
        2. `noBrokenSymlinks` reprova o build com 147 links mortos por variante. NÃO é
           workaround silenciar: são nomes de variante de cor (`folder-green.svg`,
           `folder_color_yellow_wine.svg`) cujo alvo não existe em instalação NENHUMA, nem num
           Arch — `colors/color-<X>/` usa nomes `folder-*.svg` pra sobrescrever e nunca cria os
           prefixados. Bug cosmético do upstream. Poda com `find "$out" -xtype l -delete`.
        3. `-t <cor>` fica FORA: ele copia `colors/color-<X>/` POR CIMA de `places/scalable` e
           recoloriria as pastas. A variante vazia é justamente a que foi aprovada.
      • Comentários que citavam "Fluent-dark" em launcher.nix/clipboard.nix passaram a apontar
        pro `my.theme.iconTheme`. Nome de tema hardcodado em comentário é drift esperando a vez.
      • E O TEMA SÓ NÃO BASTOU: no 1º print depois do rebuild as pastas saíram em LINE ART
        monocromática. O tema tem arte colorida em `places/16` e `places/scalable`, mas o
        `places/22` é `fill="currentColor"` — e 22 é o default. Não era regressão do Win11: o
        Fluent tinha o MESMO 22 monocromático, só não aparecia porque a visão era Compact
        (ícone grande → caía no scalable). Ou seja, quem revelou isso foi a troca pra Detalhes,
        que entrou no mesmo dia — duas mudanças juntas disfarçando a causa.
        A chave é `[DetailsMode] PreviewSize`, NÃO `IconSize`. Errei duas vezes antes de ler
        `dolphinitemlistview.cpp:172`: `previewsShown() ? previewSize() : iconSize()` — com
        preview ligado o `IconSize` é IGNORADO. Os dois foram pra 32 pro tamanho não pular
        quando o preview é desligado pra garimpar o acervo. Fica em `home/apps/dolphin.nix`.
      • Lição repetida: `grep currentColor` no SVG me fez concluir que o 16 era monocromático
        quando ele é COLORIDO (arquivo de 28 KB, cor fora do fill). Só renderizando os três
        tamanhos lado a lado o quadro apareceu. Pra ícone, RENDERIZE — não leia o XML.

- [x] "Sempre Detalhes" nunca foi Detalhes (07/08/2026) — era **Compact** desde 18/07. O pin
      do `dolphin.nix` sempre funcionou; apontava pro modo errado. `DolphinView::Mode`
      (`src/views/dolphinview.h`) é `0 = Icons, 1 = Details, 2 = Compact`, e NÃO a ordem do
      menu (Icons/Compact/Details = Ctrl+1/2/3). O `whatsthis` do kcfg ainda chama o 2 de
      "column" (nome antigo do Compact) e reforça o engano.
      • Diagnóstico foi por PRINT, não por leitura de config: abri o Dolphin e olhei. Config
        "certa" com efeito errado não se enxerga lendo o `.directory`. Se for conferir modo de
        view, olhe a tela — nome à direita do ícone e segunda coluna = Compact; Detalhes tem
        cabeçalho de coluna e uma linha por item.
      • O número cru virou `viewModeDetails` nomeado, pra não enganar de novo.
      • Migrar 2→1 exigiu ramo novo na activation: sobre chave JÁ imutável o kwriteconfig6 sai
        2 e o `set -e` derrubaria o resto do home-manager — então reescreve com sed direto.
      • Isto é a regra 14 se cumprindo pela SEGUNDA vez no mesmo arquivo: nada falhou, só
        ficou errado, por 3 semanas. Pin de KConfig sem verificação é drift esperando a vez.

- [x] MINIATURA no mount do restic custa DOWNLOAD do Drive — medido em 07/08/2026, não é
      teoria. `PreviewsShown` tem `<default>true</default>` no
      `dolphin_directoryviewpropertysettings.kcfg` (26.04.3) e não está setado aqui → preview
      LIGADO. Abri o Dolphin em `Pictures/Screenshots` do snapshot (30 arquivos, 3,9 MiB):
      +30 thumbnails em `~/.cache/thumbnails` e **+3,68 MiB lidos da rede** pelo
      `rclone serve restic` — ou seja, baixou a pasta inteira só pra desenhar ícone.
      • O `MaximumRemoteSize` do KDE (default 0 = não previsualizar remoto) NÃO protege, e o
        teste PROVA: ele está unset e o preview aconteceu de todo jeito. Mount FUSE em `/mnt`
        aparece pro KIO como caminho LOCAL, então a guarda de "remoto" nem é consultada.
      • E o limite local (`[PreviewSettings] MaximumSize`) não serve de guard: é global e as
        imagens tinham ~130 KiB cada, muito abaixo de qualquer teto sensato.
      • Não existe guard POR CAMINHO no Dolphin/KIO — conferido no kcfg e nos símbolos do
        binário. Com `GlobalViewProps=true` também não dá preview off só em `/mnt`.
      • DECIDIDO: preview fica LIGADO em tudo. `PreviewsShown[$i]=false` global foi recusado —
        miniatura vale mais no dia a dia do que a proteção contra um caso de consulta rara.
        Mitigação é manual: desligar visualização antes de garimpar o acervo. Registrado com
        ⚠️ na seção "Configurações antigas do Arch Linux", que é onde se cai ao abrir o repo.

- [x] VS Code sempre na última stable, sem edição manual (06/08/2026) — fecha a ponta solta
      que a troca de URL de ontem deixou. O pedido era "prefiro sempre deixar na latest", e a
      resposta NÃO é voltar pro `/latest/`: ponteiro + narHash travado é exatamente a quebra
      a cada release que consertamos ontem. Input que se atualiza sozinho não existe com hash
      travado — o que existe é BUMP AUTOMATIZADO.
      • `pkgs/vscode-bump.nix` (`writeShellApplication`, regra 7 — o build É o shellcheck):
        consulta `update.code.visualstudio.com/api/update/linux-x64/stable/latest`, lê o
        `productVersion` (e NÃO o `version`, que é o hash do commit), reescreve o número no
        `flake.nix` e roda `nix flake update vscode-tarball`. NO-OP quando já está na última,
        porque roda em todo `upgrade`.
      • O caminho do repo vem por ARGUMENTO (regra 11): a SSOT é `programs.nh.flake`, lida
        pelo zsh.nix via `osConfig` — o pacote não guarda literal.
      • Descartada a Action agendada: o repo ficaria atual sozinho, mas exigiria `git pull`
        antes do `upgrade` pra servir de algo, e cada bump dispararia o CI de 1,43 GiB. O
        momento em que a versão importa é o do REBUILD, então o gatilho certo é o alias.
      • De carona, os aliases pararam de se repetir: `rebuildCmd`/`updateCmd` são compostos
        no `let` e `upgrade` = `${updateCmd} && ${rebuildCmd}`. Antes `upgrade` restava os
        dois por extenso — a mesma regra em dois lugares, e no dia em que só uma cópia muda
        `upgrade` deixa de ser o que o nome diz (regra 11).
      • VALIDADO com round-trip, e é a prova que importa: baixei o `flake.nix` na mão pra
        1.131.0, rodei o bump e o `flake.lock` voltou BYTE-IDÊNTICO ao commitado (o narHash
        `sha256-PLpT3k…` da 1.132.0). `nix flake check`: all checks passed.
      • O que isto NÃO resolve: extensões e settings continuam vindo do Settings Sync (conta
        Microsoft), não do Nix — só o PACOTE é declarativo.

- [x] earlyoom NÃO protegia o compositor (05/08/2026) — o achado mais grave da limpeza, e
      apareceu por acidente: `waybar` e `mako` estavam na lista `--avoid` e são fantasmas
      (saíram na migração pro Quickshell). Ao tirá-los, medi a regex contra os processos
      VIVOS e ela casava 5 de 10 — o Hyprland ficava de fora.
      • CAUSA: o earlyoom casa `comm`, o campo do KERNEL truncado em 15 chars. O
        `wrapProgram` do nixpkgs deixa o script com o nome original e o ELF real como
        `.X-wrapped`, e quem RODA é o ELF → o comm é `.Hyprland-wrapp` e `.quickshell-wra`.
        `^(Hyprland|…)$` nunca casava. O comentário prometia "compositor nunca morre" e o
        efeito era o oposto do escrito.
      • Agora `^[.]?(…)` sem `$`, casando 16 processos vivos. Entrou `quickshell` (hoje é
        barra, OSD E daemon de notificação) e `hyprpaper`.
      • PEGADINHA DENTRO DA PEGADINHA: escrevi `"^\\.?"` primeiro, e a barra NÃO CHEGA — o
        módulo entrega os args por `Environment=EARLYOOM_ARGS=…` e o systemd descarta `\.`
        como escape inválido. O daemon logava `'^.?(…)'`. Classe de caractere `[.]` não tem
        barra pra perder. LIÇÃO: conferir no que o DAEMON parseou, nunca no .nix —
        `journalctl -u earlyoom | grep 'avoid killing'`.

- [x] Backup migrou do HDD pro Google Drive, verificado (05/08/2026) — o Seagate guardava a
      ÚNICA cópia do home vivo, num Momentus 7200.4 de ~2009 com 840 mil load cycles e 348
      erros de CRC, DENTRO da máquina. Não foi espaço: o Drive tem 4,95 TiB livres de 5 TiB.
      Cópia offsite ganha nos modos de falha que acontecem (disco morre, roubo, incêndio);
      perde em restauração pela rede e passa a depender da conta Google.
      • Medido: 1º snapshot 40,6 GiB lidos → 23,6 GiB no fio, 15 min, 255 mil arquivos. O
        incremental seguinte: 33 s e 170 MiB. `check --read-data` relendo 189 packs: "no
        errors were found".
      • Três coisas que repo REMOTO exige e local não: `--pack-size=128` (no Drive o custo é
        por CHAMADA de API, não por byte), `checkOpts = []` (o `--read-data-subset=10%` do
        local RELÊ, e reler remoto é BAIXAR — seriam GB/dia pra sempre) e
        `--max-repack-size=2G` (poda remota reempacota).
      • BUG que isso destapou: o backup FALHAVA de forma INTERMITENTE com
        `lstat /home/v1cferr/FAI-workstation: permission denied` → restic sai 3. É mount FUSE
        do USUÁRIO e o backup roda como ROOT, que não entra em FUSE alheio; só acontecia com
        a VPN da FAI de pé. E como `backup` é o 1º de TRÊS ExecStart, o `forget --prune` NÃO
        rodava — a retenção silenciosamente não se aplicava naqueles dias.
        `--one-file-system` não salva: ele impede DESCER, mas o lstat do ponto acontece.
      • O repo do Seagate NÃO foi apagado: o Drive tem 1 snapshot e ele tem 13, com janela de
        6 meses. Apagar hoje perderia toda versão anterior a hoje.
      • Aliases novos: `backup-browse` (monta o repo como pasta, um dir por snapshot) e
        `backup-verify`. O rclone NÃO decifra restic — quem decifra é o restic.

- [x] ~/Drive = raiz do Google Drive MONTADA, não sincronizada (05/08/2026) — comecei com
      `rclone bisync` e trocei por `rclone mount` depois de LISTAR o remote, que é o passo que
      eu devia ter dado ANTES: a raiz tem ~19,6 GiB de acervo real (Documentos, César, Mãe,
      SENAC…), e a pasta dedicada que eu havia inventado nasceria VAZIA — não resolvia o
      "preciso de um arquivo que está no Drive".
      • Mount ganha aqui: zero download (bisync baixaria os 19,6 GiB pro NVMe pro MESMO
        acesso) e sync PROPAGA — apagar local apagaria no Drive, inclusive pasta de família.
      • `Type=notify` (está no `rclone mount --help`): a unit só fica "started" depois do
        mountpoint pronto, senão o Dolphin abre antes e cacheia "vazia".
      • `--exclude BACKUPS_EX-B560M-V5/**`: esconde ~48 GiB de blob restic do gerenciador de
        arquivos. Não é estética — um Delete sem querer ali CORROMPE o backup.
      • Duas armadilhas pagas: (1) bisync não cria a pasta de destino e o remédio que ele
        sugere também falha; (2) o rclone RENOVA o token OAuth e tenta persistir no arquivo
        de config — contra o secret do sops (0400) isso vira `Failed to save config`, então a
        unit copia pra `%t` (tmpfs, 0600) e passa `--config` no comando. O `--config` no
        comando e não `RCLONE_CONFIG` no ambiente porque exportar faria o mount da FAI
        procurar o remote `faiws` no arquivo errado.
      • E o mount não subia porque `~/Drive` tinha um `RCLONE_TEST` órfão de 0 byte que a
        versão bisync criou: o rclone recusa mountpoint não-vazio, e `--allow-non-empty` fica
        fora de propósito (montar por cima ESCONDE o arquivo). Se não subir: `ls -a ~/Drive`
        antes de suspeitar da rede.

- [x] Opção se DECLARA no system/, se DEFINE no hosts/ (05/08/2026) — virou a convenção 6 do
      README. Os conectores de monitor (`DP-2`/`HDMI-A-3`) tinham `default` em
      system/desktop/monitors.nix e o painel `my.services` morava em system/services/toggles.nix.
      Com um host só é invisível; no host nº 2 o system/ passa a MENTIR (um laptop herdaria
      conectores que não tem e subiria Jellyfin/Sunshine por default). Agora o system declara
      as opções e o `hosts/nixos-kingston/services.nix` responde. Os defaults de monitor
      saíram de propósito: host que esquecer QUEBRA no eval, alto e cedo.
      A declaração de `my.services` segue central e NÃO foi distribuída por módulo porque
      `osConfig` só enxerga o namespace do NixOS — as chaves lidas pelo home/ (dropbox,
      discord-rpc, cs2-backup) precisam de um módulo de SISTEMA de qualquer forma.

- [x] O gate passou a CONSTRUIR, não só avaliar (05/08/2026) — o `nix flake check` constrói o
      que está em `checks` e de `nixosConfigurations` só exige que o toplevel SEJA uma
      derivação. Medido: imprimia "running 1 flake checks" e só o pre-commit era construído.
      O frágil aqui não é avaliação, é EMPACOTAMENTO: os 3 patches do nxbender, o
      `sourceRoot = "source"` do vscode e o wrapProgram sobre o .deb do claude-desktop são
      suposições sobre árvore de TERCEIRO — quebram no build, depois do `update`, e como
      `upgrade` é `update && nh os switch`, a quebra caía no meio do switch. Agora
      `packages.x86_64-linux` expõe os quatro (`nix build .#nxbender`) e `checks.pacotes` os
      constrói. De propósito NÃO é o system.build.toplevel: arrastaria o quickshell (Qt/C++)
      pro runner.
      E foi ele que pegou a primeira vítima no mesmo dia: a URL `/latest/` do VS Code é
      PONTEIRO — saiu a 1.132.0, o ponteiro andou e o narHash travado (da 1.131.0) parou de
      casar. Aqui passava porque o tarball velho estava na store; em máquina LIMPA o flake não
      avaliava mais. Não era risco de 2032, era quebra a cada release. Trocado por URL
      versionada (`/1.132.0/`), que é imutável — o preço é que `nix flake update` não sobe
      versão sozinho, subir é editar o número.

- [x] Caça ao código e à doc mortos (05/08/2026) — apagados `pkgs/README.md` (dizia "vazio por
      ora" com 2 derivations dentro, e apontava pra uma "fase 5 do README" que não existe),
      `home/desktop/quickshell/bar-preview.qml` (o próprio arquivo definia quando morrer: "quando
      a barra atingir paridade, é ligada no shell.qml e a Waybar sai" — as duas coisas
      aconteceram), `scripts/healthcheck.sh` (zero referência em .nix e o cabeçalho se dizia
      "gitignored" estando VERSIONADO — o `.sh` solto que a regra 7 proíbe) e o `.env` órfão.
      Mais ~6 comentários que descreviam um mundo que não existe (as "FASES" do Bar.qml,
      `nvidia-smi` numa máquina Intel, `waybar` em duas listas de categoria).
      AUDITADO e limpo: zero `.nix` órfão, zero input de flake sem consumidor (12 conferidos),
      toda opção `my.*` com consumidor.
      LIÇÃO: o pior legado não é arquivo sobrando — é LISTA ENUMERANDO PROGRAMA REMOVIDO. O
      `waybar`/`mako` mortos no `--avoid` do earlyoom escondiam que o compositor nunca estava
      protegido. Doc morta ali não era sujeira, era bug disfarçado.

- [ ] 🔴 REVOGAR a auth key do Tailscale que estava no `.env` órfão (achado em 05/08/2026)
      O arquivo `.env` na raiz do repo guardava `TAILSCALE=tskey-auth-kLXAR6…` em TEXTO CLARO,
      modo 644, cabeçalho "nixos-sandisk declarative join (**reusable**)". Não era versionado
      (`*.env` no .gitignore) e NADA lia: o join de hoje usa
      `authKeyFile = config.sops.secrets.tailscale_authkey.path` (system/net/tailscale.nix:18).
      Sobra do host ANTIGO, de 27/07 — anterior ao cutover.
      • Key REUSABLE é o pior caso: quem tiver a string entra na tailnet quantas vezes quiser.
      • O arquivo foi APAGADO. Revogar não precisa da string, só do ID: no admin console,
        Settings → Keys → a que começa com `kLXAR6`.
      • Enquanto não revogar, a key vale mesmo sem o arquivo. Apagar reduziu a exposição
        local; não invalidou nada.
- [x] Nó `nixos-sandisk` REMOVIDO da tailnet (05/08/2026) — sobrava offline há 4 dias de uma
      máquina que não existe mais (o SanDisk virou Windows 11); nó morto é ACL e rota que
      ninguém audita. Feito no admin console; sobraram 2 (nixos-kingston, faidell6035).
      • POR QUE ESTES DOIS NÃO VIRAM DECLARATIVOS (pesquisado em 05/08/2026, regra 1): o
        CLI OFICIAL não faz nenhuma das duas coisas. `tailscale --help` da 1.98.10 (a que
      está instalada) tem 30 subcomandos e nenhum é `key` ou `device` — o mais perto é
      `logout`, que expira o node key DESTA máquina, não remove nó alheio. A doc oficial de
      "Remove a device" diz console ou API, sem CLI, e a FR do upstream
      (tailscale/tailscale#8844) segue aberta. As duas ações são da API v2:
      `DELETE /api/v2/device/{id}` e `DELETE /api/v2/tailnet/{tailnet}/keys/{keyId}`, em
      `https://api.tailscale.com`.
      DECISÃO: fazer no admin console e NÃO guardar token de API. Automatizar exigiria um
      token/OAuth client com escrita na tailnet inteira, guardado no sops — um segredo
      PERMANENTE e mais poderoso que a auth key que se quer revogar, criado para uma tarefa
      de UMA VEZ. Só compensa se um dia existir rotina recorrente (ex.: podar nó parado),
      e aí o certo é OAuth client com escopo mínimo, não API key de admin.
      (Detalhe da doc que importa: revogar a key NÃO desautoriza quem já entrou com ela —
      são ações independentes, e é por isso que as duas estão nesta lista.)
      O CLI, aliás, JÁ é declarativo: vem de `services.tailscale.package`
      (system/net/tailscale.nix), não de lista de pacotes. Pôr `tailscale` em
      `system/packages.nix` seria o mesmo pacote em dois lugares — fura a regra 4.
- [x] Arquivo do Arch VERIFICADO e o módulo APAGADO (05/08/2026) — fim do ciclo de vida que
      o próprio `system/services/restic-arch-kingston.nix` tinha escrito: "depois do check
      --read-data passar e o Kingston estar formatado, apague este arquivo".
      • `sudo restic-arch-kingston check --read-data` → `no errors were found`, lendo os
        **189 packs** (1 snapshot, 7 índices) do repo no Drive. Isso é o que separa "subiu"
        de "dá pra restaurar": relê os dados, não só o índice.
      • Saíram o módulo, o import em `system/services/default.nix`, a chave
        `arch-kingston-archive` do `toggles.nix` e o `true` do painel do host.
      • FICARAM de propósito: os repos, o segredo `restic_password_arch_kingston` (índice do
        Bitwarden) e o `rclone_gdrive_conf`. São a CHAVE de um acervo vivo — o módulo era o
        que ESCREVIA, não o que dá acesso.
      • Efeito colateral que virou correção: apagar o módulo levava os wrappers
        `restic-arch-kingston*`, e `restic` NÃO estava no PATH — o `services.restic` do
        nixpkgs só gera wrapper por repo. O acervo teria ficado inalcançável sem `nix
        shell`. Entrou `restic` no `system/packages.nix` (critério "resgate"), e os comandos
        sem wrapper estão na seção "Configurações antigas do Arch Linux" acima.
      • A perna do Seagate NÃO foi read-verificada e não vai ser: decidido em 05/08 ficar
        SÓ com a cópia do Drive. Verificar um repo que vai ser apagado é trabalho jogado fora.
- [x] Segundo destinatário age no cofre sops (04/08/2026) — o `.sops.yaml` tinha UMA chave, e
      sops não tem recuperação: perder aquela chave = perder TODO segredo do repo, para sempre.
      O único backup dela era o Bitwarden, então o desenho tinha um ponto de falha capaz de
      dano permanente (os outros riscos do repo custam tempo, não dados). Agora são dois
      destinatários: `host_nixos_kingston` (a de sempre, em /var/lib/sops-nix/key.txt) e
      `backup_offline`.
      • `creation_rules` só vale pra arquivo NOVO — adicionar a chave no `.sops.yaml` NÃO
        re-encripta o que já existe. Quem faz isso é `sops updatekeys -y secrets/secrets.yaml`,
        rodando como root (a chave atual é dele) e com `chown v1cferr:users` + `chmod 644`
        depois, senão o arquivo do repo fica do root.
      • VERIFICADO decriptando o cofre com a chave de backup ISOLADA (`SOPS_AGE_KEY_FILE`
        apontando só pra ela). Sem esse teste o backup seria imaginário — e o `updatekeys`
        imprime "already up to date" mesmo quando faz o serviço, então a mensagem dele não
        serve de prova. A prova é decriptar, ou os dois `recipient:` dentro do secrets.yaml.
      • Efeito colateral bom: `restic_password` mora DENTRO do cofre, então recuperar o cofre
        recupera a senha do restic — perder o Bitwarden não faz mais os repos virarem tijolo.
      • Anchor renomeado `nixos_seagate` → `host_nixos_kingston`: a chave nasceu naquele host e
        foi carregada no cutover (01/08) — mesma chave, host novo, nome velho confundia.
      FALTA a cópia OFFLINE (USB/papel em outro lugar físico): as duas cópias da privada hoje
      estão na mesma máquina e na mesma conta de nuvem (~/ e ~/Dropbox, texto claro, escolha
      consciente). Enquanto for assim, o segundo destinatário protege contra perder a chave do
      host, não contra perder a conta/máquina.
- [x] CI passou a rodar `nix flake check` DE VERDADE (04/08/2026) — o workflow rodava
      statix/deadnix/nixfmt direto do nixpkgs porque o input privado `duo-streak-daemon` faria
      o `flake check` exigir deploy key (o Nix busca TODOS os inputs do lock ao avaliar, não só
      os que a saída usa). Isso deixava dois furos: o CI não verificava que o
      `nixosConfigurations` AVALIA (erro de módulo passava verde até o rebuild), e os três `nix
      run` eram uma TERCEIRA definição da mesma regra que o flake.nix e o pre-commit já
      definiam — drift da regra 14 esperando acontecer.
      • A saída foi `--override-input duo-streak-daemon path:./ci/stub-duo`: troca o input
        ANTES do fetch, então nenhuma credencial entra no CI. Diretório VAZIO basta porque o
        único consumidor (`system/services/duo.nix`) usa o input só como contexto de build do
        Docker — interpolação de path, sem `readFile` em avaliação. Se algum dia um módulo LER
        arquivo do repo privado, o stub precisa daquele arquivo (ou volta o plano B da deploy
        key, que ficou registrado no fim do workflow).
      • Sumiu o `env NIXPKGS` que existia só pra fixar a versão dos linters: eles agora vêm do
        flake.lock, iguais aos de casa por construção. Mexer nos hooks do flake.nix muda o CI
        sozinho, sem editar o workflow.
      • CUSTO aceito: o check busca os ~1,43 GiB de inputs e avalia a config inteira, então o
        CI foi de segundos pra minutos. Tempo de máquina por cobertura e por uma definição só.
- [x] Arquivo off-line dos inputs do flake (04/08/2026) — `nix flake archive --to
      file:///home/v1cferr/flake-archive`, que entra no restic do home (o `restic.nix` cobre
      /home/v1cferr e não exclui esse caminho) → fica versionado e verificado pela máquina que
      já existe, em vez de uma cópia crua. Medido: 18 inputs, 1,43 GiB na store → **319 MiB**
      no archive (o cache `file://` comprime com xz, e é por isso que demora alguns minutos).
      • VERIFICADO de verdade, não por "os arquivos estão lá": cada input foi CONSULTADO de
        volta com `nix path-info --store file:///home/v1cferr/flake-archive <path>`, 0 faltando.
      • PEGADINHA na hora de verificar: o `--dry-run` lista também o path do flake RAIZ, que
        com a árvore SUJA muda a cada edição — ele aparece como "faltando" no archive sem que
        nada esteja errado. O archive é dos INPUTS; o repo em si tem o git como backup.
      • POR QUE: o `flake.lock` fixa IDENTIDADE, não DISPONIBILIDADE, e flakes não têm mirror
        (não existe `?mirrors=` como no fetchurl). Metade dos inputs é de mantenedor único ou
        self-hosted — `quickshell` só existe em git.outfoxxed.me. Se aquele servidor sair do
        ar, o input é inbuscável e o rev travado não ajuda em nada.
      • O que isso NÃO compra: rebuild offline completo. As fontes de cada pacote do nixpkgs
        continuam vindo do cache/upstream. Pra bootar sem construir nada, o que se arquiva é o
        closure do sistema (`nix copy` do system.build.toplevel) — dezenas de GB, outra decisão.
      PENDENTE virar declarativo (regra 3): hoje é comando na mão e envelhece no próximo `nix
      flake update`. Dono natural = timer systemd re-arquivando, e o restic deduplica, então
      re-arquivar só adiciona os inputs que mudaram.
- [x] BTRFS bem configurado (02/08/2026) — auditado o FS depois do cutover. O que existia
      (noatime, space_cache=v2, subvolumes, scrub mensal) estava certo; o que faltava virou
      system/hardware/btrfs.nix (POLÍTICA, machine-agnostic atrás de "a raiz é btrfs?") +
      system/services/btrbk.nix (snapshots). O LAYOUT continua no disko.nix.
      • SNAPSHOTS (a maior lacuna): btrfs sem snapshot é ext4 com checksum. btrbk horário do
        @home, retenção 48h/7d/4w, `snapshot_create=onchange` (senão máquina ociosa gera 24
        snapshots idênticos/dia e empurra os úteis pra fora). NÃO substitui o restic — ele
        mora no MESMO disco; cobre "sobrescrevi há 20 min", o restic cobre "o disco morreu".
        Só @home: a raiz já tem rollback por geração no GRUB, e snapshot de `/` nem pegaria
        o /nix (subvolume separado — snapshot não desce pra subvolume aninhado).
      • zstd:3 → zstd:1: num Gen4 de ~7 GB/s o gargalo vira o COMPRESSOR. Descompressão tem
        a mesma velocidade nos dois níveis ⇒ leitura não perde nada, e cada rebuild ganha.
        Só vale pra escrita NOVA; reescrever exigiria `defragment -czstd`, que QUEBRA reflink.
      • fstrim.timer DESLIGADO: `discard=async` (default do kernel desde 6.2, agora explícito
        no disko) já é a mesma operação, enfileirada e com rate limit. Os dois juntos = TRIM
        em duplicata. Se tirar o discard=async do disko, religar o fstrim no MESMO commit.
      • Reclaim automático de block group ligado (dynamic_reclaim + periodic_reclaim, kernel
        6.11+, vinham 0). É o substituto IN-KERNEL do cron de `btrfs balance -dusage=N` do
        btrfsmaintenance — e melhor, porque sabe quando NÃO vale relocar. bg_reclaim_threshold
        fica intocado: é mutuamente exclusivo com o dynamic (EINVAL).
      • Alarme: o scrub falhava em SILÊNCIO. Agora OnFailure → notificação crítica em toda
        sessão viva + journal. Somado a isso, checagem DIÁRIA de `btrfs device stats -c`:
        o scrub é mensal, um NVMe que começa a morrer no dia 2 ficaria 28 dias sem aviso.
        Contador não zera sozinho — reconhecer com `device stats -z` DEPOIS de investigar.
      • `+C` (nodatacow) nos diretórios de banco (volumes do Docker, SQLite do Jellyfin):
        CoW + escrita aleatória de 8 KiB fragmenta sem parar. Só pega arquivo NOVO, e
        desliga o checksum desses arquivos — trade-off consciente, os dois são refazíveis.
      PASSO MANUAL ÚNICO (subvolume não nasce em rebuild — o disko só roda em instalação):
        sudo mount -o subvolid=5 /dev/nvme0n1p2 /mnt && sudo btrfs subvolume create /mnt/@snapshots && sudo umount /mnt
      O `nofail` no /.snapshots existe pra que esquecer esse passo custe "btrbk não roda"
      (RequiresMountsFor) em vez de "boot cai no emergency shell".
      NÃO ligar qgroups/quota: mata a performance do btrfs e é o motivo de metade dos
      relatos de "btrfs lento". Nada aqui precisa deles.
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
- [x] DUALBOOT com tema minegrub + SECURE BOOT (02/08/2026) — systemd-boot → GRUB, tema
      "seleção de mundo" do Minecraft, Windows 11 no menu e Secure Boot ligado nos dois SOs.
      system/core/boot.nix (o boot-grub.nix dormente foi absorvido) + system/core/secureboot.nix.
      O QUE DECIDIU A ARQUITETURA, e não foi gosto: **as duas ESPs estão em discos
      diferentes** (NixOS em nvme0n1p1, Windows em sdb1). O systemd-boot só carrega binário
      EFI da PRÓPRIA ESP — ele é incapaz de listar o Windows, e trocar de SO viraria F8 no
      POST toda vez. Isso derruba o LANZABOOTE junto, que é systemd-boot-only e é o caminho
      oficial de Secure Boot no NixOS. Sobra GRUB (lê as duas ESPs, e é o que o tema exige)
      + assinatura à mão via sbctl. Não há módulo NixOS que assine o GRUB.
      HONESTIDADE SOBRE O QUE ISSO PROTEGE: a firmware verifica o GRUB e o bootmgfw da
      Microsoft; o GRUB carrega kernel/initrd SEM verificar (não tem shim). Satisfaz a
      firmware e o Windows e barra bootloader trocado por fora; não barra quem já tem root.
      A cadeia inteira só com lanzaboote — e aí sem menu e sem tema.
      ⚠️ `enroll-keys -m` (com os certificados da Microsoft) NÃO É OPCIONAL: sem ele,
      apagar as chaves de fábrica derruba o Windows E a option ROM da Arc B580. E o timing
      importa: o CA da Microsoft de 2011 EXPIROU em junho/2026. Conferido nesta máquina em
      02/08 — a BIOS 2803 já traz as duas gerações no `db` (2011 + os três CAs de 2023) e o
      sbctl 0.18 embute as seis, então o `-m` cobre também o Windows pós-rollover. O
      `--firmware-builtin` NÃO serviria: o `dbDefault` desta firmware está vazio.
      PEGADINHA DO TEMA: os ícones casam por `--class`, NÃO pelo título — e erra em
      silêncio (ícone genérico, sem texto). `nixos` vem do default `entryOptions`; `windows`
      é derivado pelo 30_os-prober da PRIMEIRA palavra do label "Windows Boot Manager"
      (logo, "windows", nunca "windows11"); `submenu` é o das gerações antigas. O texto das
      2 linhas é RENDERIZADO DENTRO do PNG na fonte do Minecraft, e o título do GRUB é
      empurrado pra fora da tela pelo tema (`item_icon_space = 2000`) — por isso todas as
      gerações mostram a mesma descrição: compartilham a classe `nixos`. Limitação do tema.
      ESCOLHA DO TEMA: o link original era o minegrub-theme (menu principal do Minecraft),
      preterido pelo minegrub-world-sel-theme (mesmo autor) — a tela de seleção de mundo dá
      ícone + descrição POR SO, que é o que um dualboot quer; no menu principal a entrada
      é só um botão.
      MEDIDO ANTES: a ESP de 1 GiB aguenta as 10 gerações. O install-grub.pl liga o
      copyKernels sozinho (o /boot está noutro filesystem que o /nix/store — o que também
      evita depender do GRUB ler btrfs+zstd) e nomeia por hash da store, então gerações que
      compartilham kernel ocupam espaço uma vez: 13 MiB + 47 MiB por versão de kernel.
      Runbook dos passos MANUAIS (Setup Mode só se entra pela BIOS) no cabeçalho do
      secureboot.nix, junto do porquê de cada um.
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
        ⚠️ `/var/lib/sbctl` É O PRIMEIRO DA LISTA e o único que faz a máquina NÃO BOOTAR se
        for esquecido: são as chaves de Secure Boot (ver system/core/secureboot.nix). Sem
        elas o switch seguinte não assina o GRUB, e com Secure Boot ligado a firmware
        recusa o bootloader. Recuperação = desligar SB na BIOS + `sbctl create-keys` +
        `enroll-keys -m` de novo, com a BIOS em Setup Mode. Declarar ANTES de ligar a raiz efêmera.
      FALTA só: o snapshot `@-blank` (base do rollback) e a lista de persistência. O blank NÃO
      é now-or-never — subvolume vazio criado depois é idêntico a snapshot em branco.
      ── LIDO O CÓDIGO DO FOUNDRY (02/08/2026), o que muda no plano ──────────────
      CORREÇÃO DE PREMISSA: btrfs NÃO é obrigatório pra impermanência — o caminho mais
      comum na comunidade é raiz em tmpfs, e com bind mount ela roda até em ext4. A escolha
      segue CERTA, mas pelo motivo certo: btrfs dá raiz efêmera sem gastar RAM, e RAM é
      exatamente o que falta aqui (15 GB). Não repetir "é obrigatório".
      São só dois arquivos no Foundry: `hosts/common/optional/ephemeral-btrfs.nix` (o wipe)
      e `hosts/common/global/optin-persistence.nix` (a lista). O resto da persistência é
      DISTRIBUÍDO — cada módulo de serviço declara o que ele precisa guardar (openssh.nix,
      podman.nix, jellyfin.nix…). Esse é o padrão a copiar: casa com system/services/*.nix.
      ⚠️ `/srv` É O MAIOR RISCO, e não estava anotado: NÃO é subvolume, mora em `@`, e é onde
      vive a biblioteca do Jellyfin (132 GiB). O Foundry persiste `/srv` explicitamente. Ligar
      a raiz efêmera sem isso APAGA a biblioteca no primeiro boot. Antes do sbctl na lista.
      Lista mínima do Foundry, toda ela aplicável aqui: `/etc/machine-id` (arquivo, não dir),
      `/var/lib/systemd`, `/var/lib/nixos`, `/srv`. O `/var/lib/nixos` é o MAPA DE UID/GID —
      perder = reatribuição de uid, que é a MESMA classe de bug que quebrou Docker/Postgres/
      Sunshine no cutover (ver o dano do cutover). `/var/log` NÃO entra: o Foundry lista
      porque não tem subvolume pra isso; aqui o `@log` já resolve, e declarar os dois faria
      um bind mount por cima do subvolume.
      `neededForBoot = true` no `/persist` (o Foundry seta; hoje está false no disko).
      `dont-wipe`: arquivo marcador no topo do filesystem que faz o script PULAR o wipe.
      COPIAR — é a diferença entre "boot loop" e "toco um arquivo pelo live USB".
      SYSTEMD INITRD ANTES, em commit separado: o Foundry roda `boot.initrd.systemd.enable`
      e o script tem dois caminhos; o de `postDeviceCommands` é o legado. Ligar o systemd
      initrd sozinho, rebootar e confirmar — só depois somar o wipe. Dois riscos de boot
      num commit só é o jeito de não saber qual dos dois quebrou.
      Adaptar nomes no wipeScript: o Foundry usa `root`/`root-blank`/`persist`; aqui é
      `@`/`@-blank`/`@persist`. Errar isso não dá erro de avaliação — dá boot quebrado.
      Copiar também o workaround do impermanence#254 (`/var/lib/private` em 0700 +
      `RemainAfterExit = false` no systemd-tmpfiles-resetup), senão serviço com DynamicUser
      quebra. E `@snapshots` (btrbk) sobrevive por desenho: é top-level, não vive dentro de `@`.
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
- [x] Remover todos os outros hosts e manter apenas o atual — hoje só hosts/nixos-kingston/.
      O nixos-sandisk saiu em 02/08/2026: o disco dele virou o Windows 11, então o host não
      era mais nem rollback nem alvo. Molde pra host novo se pega no histórico do git.
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
        — Ollama NATIVO (system/services/ollama.nix), **na GPU (Arc B580) por Vulkan**
        desde 06/08/2026. qwen3:4b (solver texto) + bge-m3 (embeddings)
        via loadModels. É o solver local do duo-streak-daemon (localhost:11434),
        sem cota nem nuvem.
  - [x] Ollama na GPU da Arc B580 (06/08/2026) — era o "explorar depois" que ficou
        pendente na troca de placa. `services.ollama.acceleration` NÃO existe mais
        (`mkRemovedOptionModule`): aceleração virou escolha de PACOTE, e `pkgs.ollama`
        puro é igual ao `-cpu` quando não há rocmSupport/cudaSupport — ou seja, o
        "CPU-only" antigo não era limitação do nixpkgs, era o default. Solução de 1
        linha: `package = pkgs.ollama-vulkan` (0.32.3, já no 26.05).
        VULKAN e não SYCL/ipex-llm porque o Vulkan usa o Mesa ANV que já está no
        sistema — nada novo pra empacotar (o ipex-llm não está no nixpkgs).
        Medido no startup: `library=Vulkan description="Intel(R) Arc(tm) B580
        Graphics (BMG G21)" type=discrete total=11.9 GiB available=9.7 GiB`. O
        `llvmpipe` (Vulkan em CPU, aparece como GPU1 no vulkaninfo) é descartado
        pelo próprio ollama — não precisou de `GGML_VK_VISIBLE_DEVICES`.
        Hardening do módulo já libera a placa: `DeviceAllow` tem `char-drm`
        (major 226 = /dev/dri/*) e `SupplementaryGroups = [ "render" ]`.
        ⚠️ Risco conhecido: crash do backend Vulkan em Arc sob decode de alta
        frequência (ollama#14207). Fallback = `pkgs.ollama-cpu`, 1 linha.
        CONSEQUÊNCIA de arquitetura: o Mesa agora é caminho crítico de IA, não só
        de jogo — reforça o item do driver/unstable abaixo.
  - [x] Claude Desktop (GUI: Chat/Cowork/Code) — 02/08/2026. A pesquisa mudou de resposta no
        meio do caminho: em **30/06/2026 a Anthropic passou a publicar um Claude Desktop
        OFICIAL pra Linux** (beta, `.deb` num APT próprio, só Debian/Ubuntu homologados).
        Isso APOSENTA os projetos que faziam engenharia reversa do binário de macOS/Windows,
        que era todo o estado da arte até então. NÃO está no nixpkgs: a issue #366213
        (Package request) foi FECHADA e o canal só tem claude-code/claude-monitor.
        ESCOLHIDO `aaddrick/claude-desktop-debian` (5.3k ★, releases automáticas seguindo a
        versão upstream), que REEMPACOTA o .deb oficial desde a v3.0.0 — `dpkg-deb` +
        `autoPatchelfHook`, o padrão nixpkgs de vendor binário (discord/vscode). PRETERIDOS:
        `k3d3/claude-desktop-linux-flake` (o pioneiro e o mais citado nas buscas, mas fazia RE
        do módulo nativo e está PARADO desde nov/2025 — anterior ao release oficial) e
        `heytcass/claude-for-linux` (extrai do DMG do macOS; 6 ★ e 77 issues abertas).
        Critério além de popularidade: o aaddrick NÃO usa o electron do nixpkgs (mantém a
        árvore co-locada pra `/proc/self/exe`/`resourcesPath` resolverem) e NÃO desliga o
        sandbox — o `chrome-sandbox` vem SUID, a store não carrega SUID, e em vez do
        `--no-sandbox` que a maioria dos forks usa ele conta com o userns sandbox.
        VARIANTE **FHS** e não a pura: os servidores MCP precisam achar node/uv, e o Cowork
        sobe uma VM QEMU de verdade procurando `/usr/share/OVMF/*.fd` e `/usr/bin/virtiofsd`
        em caminhos FHS HARDCODED — fora do FHS ele só responde `virtualization_tools_missing`.
        Closure MEDIDO 2.9 GiB (o qemu_kvm é a maior fatia).
        Integrado por **`overlays.default`** e não por `packages.<system>` (que é o padrão
        do zen-browser/browser-previews aqui): conferi ANTES que os 13 atributos que o pacote
        usa (libgbm, addDriverRunpath, qemu_kvm, OVMF…) existem no 26.05, então dá pra buildar
        contra a base estável em vez de arrastar um 3º nixpkgs pro lock — o input dele é
        `nixpkgs-unstable`, e `follows` sozinho NÃO resolveria (o overlay usa o `final` de
        quem consome, ignorando o input dele).
        ⚠️ COWORK NÃO FUNCIONA nesta máquina até um passo MANUAL na BIOS: o kernel diz
        `x86/cpu: VMX (outside TXT) disabled by BIOS` e `kvm_intel: VMX not enabled` — não
        existe `/dev/kvm`. Ligar "Intel Virtualization Technology (VT-x)" (mesma visita do
        Secure Boot) e SÓ ENTÃO somar `users.users.v1cferr.extraGroups = [ "kvm" ]`, que não
        entrou aqui por não ser validável sem o device. O `/dev/vhost-vsock` JÁ existe.
        Chat e Code funcionam sem nada disso.
        Achados de execução: `--doctor` NÃO é flag reconhecida nesta versão (ela abre a GUI);
        o app sobe em Wayland NATIVO sozinho, então o `CLAUDE_USE_WAYLAND=1` que a doc oficial
        manda usar é desnecessário aqui. Falta do beta Linux: Computer Use e ditado.
        ESTADO (regra 6 → restic): sessão/login e `~/.config/Claude/claude_desktop_config.json`
        — e o app REESCREVE esse JSON em runtime, então pela regra 14 o Nix não é dono dele.
        ⚠️ KEYRING: no 1º login o app avisa "your sign-in won't be saved" e pede login TODA
        vez. NÃO é o keyring (conferido: `org.freedesktop.secrets` no bus e `collection/login`
        presente — não é o caso do keyring-após-restore). É o Electron autodetectando o backend
        de secret pelo XDG_CURRENT_DESKTOP: "Hyprland" não casa com nenhum caso do os_crypt do
        Chromium, ele cai no "basic text" e o safeStorage se declara indisponível. MESMO bug e
        MESMO remédio do VS Code, mas sem `commandLineArgs` (não é o electron do nixpkgs) —
        entra por wrapper (`overlayClaudeKeyring` no flake.nix). Só o `claude-desktop` é
        embrulhado: o overlay do upstream monta o `-fhs` sobre `final.claude-desktop`, que é o
        do FIXPOINT, então a variante FHS herda o wrap sozinha — não precisou tocar no fhs.nix
        dele. Regra geral: TODO Electron novo aqui vai precisar de `--password-store=gnome-libsecret`.

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
      Battlemage OK no kernel 6.18/Mesa 25.x. O Ollama ficou em CPU na troca e VOLTOU
      pra GPU em 06/08/2026 via `pkgs.ollama-vulkan` (ver item do Ollama acima).
      Pra ressuscitar a NVIDIA: histórico git do system/hardware/gpu.nix.
- [x] Driver da Intel no canal UNSTABLE — TENTADO, TESTADO e REPROVADO (06/08/2026).
      A ideia era "driver sempre na última versão, porque a Intel atualiza toda semana".
      Ela morre no fato de que driver gráfico no NixOS não é lib normal: é PLUGIN
      carregado impuramente de `/run/opengl-driver/lib`, e o LOADER vem do canal da
      base. Loader aceita driver igual ou mais VELHO que ele, nunca mais novo — o
      `libva` varre `__vaDriverInit_1_<minor>` do seu minor até `1_0` e não tenta
      acima. Medido: `intel-media-driver` do unstable exporta `1_24`, o `libva`
      2.23.0 do estável para em `1_23` → `vaInitialize failed with error code -1`,
      e TODO decode/encode cai pra CPU **em silêncio** (regra 14: nada falha, só
      fica errado). Problema conhecido da comunidade (nixpkgs #263940, #216361).
      ⚠️ **O MESA É EXCEÇÃO** — medido DEPOIS, e é o oposto do que eu tinha
      concluído: o `libgbm` virou pacote SEPARADO (stub que linka o do host em
      runtime) e o 25.05 introduziu `hardware.graphics.package` exatamente pra
      "gerenciar a versão global do Mesa sem mass rebuild". Testado: ICD do
      `unstable.mesa` + vulkan-loader do sistema → `deviceName = Arc B580`,
      `driverInfo = Mesa 26.1.6`; EGL idem, sem erro. Ou seja: **Mesa PODE cruzar
      canal** (loader de Vulkan/GL negocia versão), `libva` NÃO (só desce de
      minor). Não é a mesma classe de problema, apesar de parecer.
      E o ganho não existia: o nixpkgs BACKPORTA point-release pro branch de
      release — mesa 26.1.5 vs 26.1.6, e kernel 6.18.42 + linux-firmware 20260622
      IDÊNTICOS nos dois canais. Divergem só o userspace Intel (media-driver
      26.1.6→26.2.4, compute-runtime 26.18→26.27, vpl-gpu-rt 26.1.6→26.3.0) — e é
      exatamente esse que não pode atravessar o canal.
      **REGRA QUE FICA**, por lever: (a) kernel → `pkgs.linuxPackages_latest`, do
      PRÓPRIO estável, sem cruzar canal — feito, ver item do kernel; (b) Mesa →
      `hardware.graphics.package = pkgs.unstable.mesa` (+ `package32 =
      pkgs.unstable.pkgsi686Linux.mesa`, nessa ordem — `pkgs.pkgsi686Linux.unstable`
      é errado, ver flake.nix), mecanismo provado mas SÓ vale quando o delta for
      minor de verdade: revisar ~set/2026, quando o unstable for pro 26.2+ e o
      26.05 travar no 26.1.x; (c) VA-API/oneVPL/compute → fica no estável, sobe só
      com a base (26.11, ~nov/2026); (d) NÃO adotar mesa_git/cache de terceiro.
      Aviso gravado no cabeçalho do `extraPackages` em system/hardware/gpu.nix.
      Peso extra desde 06/08: o Mesa virou caminho crítico de IA também, porque o
      Ollama passou a rodar por Vulkan/ANV — não é mais só perf de jogo.
- [x] Kernel mainline (`linuxPackages_latest`, 7.1.x) — 06/08/2026, em
      system/core/boot.nix. É o lever (a) do item acima e o ÚNICO de driver que não
      atravessa canal: o `linuxPackages_latest` vem do próprio 26.05, e o driver `xe`
      da Arc mora no kernel, então kernel novo = driver novo sem risco de ABI de
      loader. Seguro nesta máquina porque não há NENHUM módulo out-of-tree (nada de
      zfs/virtualbox pra casar de versão — auditado) e o Secure Boot daqui assina o
      GRUB, não o kernel (core/secureboot.nix), então não pede re-enroll de chave.
      Sai de 6.18.42 (default do release) pra 7.1.6. Rollback = geração anterior no
      menu do GRUB. `boot` é PREFERÍVEL a `switch` numa troca de kernel, mas o
      `switch` não quebra — eu tinha escrito "NUNCA switch" e estava errado: o NixOS
      guarda `/run/booted-system/kernel-modules` com a árvore do kernel RODANDO, e
      foi o que aconteceu na prática (switch 6.18.42→7.1.6, `systemctl --failed`
      vazio, modprobe resolvendo em .../6.18.42). A vantagem do `boot` é só não
      reiniciar serviço numa geração cujo kernel ainda não subiu.

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
  - [x] CADEIA DE FALLBACK (02/08/2026) — emoji, CJK, matemática e dingbats viravam
        QUADRADINHO PIXELADO (título de stream na Twitch, planilha no Chrome). O diagnóstico
        derrubou a hipótese óbvia: fonte de emoji, CJK e cor JÁ ESTAVAM instaladas — vinham
        de graça pelo `fonts.enableDefaultPackages = true`. O defeito era a cadeia ter UM ELO
        SÓ: `sansSerif`/`serif`/`monospace` = só a SSOT, uma fonte MONOESPAÇADA que cobre
        Latin/Grego/Cirílico + os símbolos patcheados e nada mais. Tudo fora disso era
        resolvido pela ordem própria do fontconfig — ou seja, por ACIDENTE — e no fim dessa
        fila está o `unifont`, bitmap de 16px que é o único a cobrir faixas como U+0870 e
        U+2FFC (medido com `fc-list ":charset=<cp>"`). O quadradinho era ele.
        FIX: `noto-fonts` (traz NotoSansMath/Symbols/Symbols2 — as letras matemáticas 𝗥 e
        os dingbats ⁎ saem daí), `noto-fonts-color-emoji` e `noto-fonts-cjk-sans`, DECLARADOS
        mesmo os que já vinham do enableDefaultPackages: renderização não pode depender de um
        default do NixOS que ninguém pediu. E cada genérica virou lista — SSOT primeiro
        (aparência intacta), Noto no meio, `Noto Color Emoji` no FIM (no fim ele nunca ganha
        de fonte de texto, mas é alcançado direto em vez de por sorte na fila).
        ARMADILHA DE MEDIÇÃO que quase me fez concluir errado DUAS vezes: `fc-match` MENTE.
        Com família explícita (`fc-match "Noto Sans:charset=1F534"`) ele devolve a família
        pedida mesmo que ela não tenha o glifo — charset só pesa na ordenação. E sem charset
        válido ele responde qualquer coisa (respondeu `unifont` pra tudo quando meu loop
        quebrou o parsing). Quem filtra POR COBERTURA DE VERDADE é `fc-list ":charset=<cp>"`.
        NÃO É BUG: `❤` (U+2764) fica monocromático de propósito — é emoji de APRESENTAÇÃO DE
        TEXTO, só vira colorido com o seletor VS16 (`❤️`). Forçar cor exigiria regra própria.
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

- [ ] Configurar ambos os perfils do Claude (fai.ufscar.br) e do César (imagino que essa configuração esteja no meu backup da home no Google Drive que configuramos antes)
- [ ] Continuar configurando o dualboot com Secure Boot
- [x] Baixar link do MEGA por proxy/Tor (03/08/2026) — `mega-tor <link> [destino]`
      (home/net/mega.nix) + daemon Tor só-cliente com SOCKS em 127.0.0.1:9050
      (system/net/tor.nix, toggle `my.services.tor`).
      FERRAMENTA: megatools (`megadl`), 139 KiB de closure, mantido (1.11.5, jul/2025).
      É a única mantida que abre LINK PÚBLICO pela CLI **e** tem `--proxy socks5h://`
      NATIVO — o próprio man usa `socks5h://localhost:9050` (Tor) como exemplo, então
      não precisa de torsocks/LD_PRELOAD. Descartadas: rclone (o backend `mega` fala com
      CONTA; link com a chave no fragmento não é caminho de remote — rclone#7088 aberto),
      MEGAcmd (oficial, closure grande e `proxy` só HTTP(S): SOCKS é o issue #204, aberto
      desde 2019 — sem SOCKS não há Tor) e megabasterd (GUI Java; o proxy dele é LISTA de
      proxies pra furar cota, objetivo diferente).
      TRÊS COISAS DO WIKI DO NIXOS QUE NÃO VALEM AQUI (conferidas no módulo do nixpkgs,
      não presumidas): (a) `services.tor.enable` sem `client.enable` sobe o daemon SEM
      porta de saída — fica `active` e nada consegue usar; (b) o `openFirewall = true` do
      exemplo é de RELAY: o listener é 127.0.0.1, não há o que abrir, e abrir viraria
      proxy aberto na LAN; (c) a "segunda porta rápida 9063" NÃO EXISTE — o módulo gera
      UMA SOCKSPort a partir de `client.socksListenAddress`, e 9063 é só o default do
      wrapper `torsocks-faster` (services.tor.torsocks), que sem uma SOCKSPort declarada
      à mão aponta pra porta onde ninguém escuta. Por isso o torsocks ficou de fora.
      `SafeSocks 1`: recusa SOCKS4/SOCKS5-com-IP, ou seja, quem resolve DNS localmente
      toma ERRO em vez de vazar a consulta — e é por isso que o consumidor usa socks5h.
      LAÇO PACIENTE (o wrapper é um só, `mega-dl`, com transporte por flag — o `mega-tor`
      da 1ª versão virou `--tor`): tenta, e em falha RETOMA até o arquivo fechar ou até o
      teto de 48h. Retomada é o que faz isso valer: o parcial mora em `.megatmp.<id>` no
      destino, o resume é o DEFAULT (`--disable-resume` é que desliga) e é keyed pelo ID
      DO ARQUIVO, não pelo transporte — MEDIDO: comecei por Tor e continuei direto do
      mesmo parcial. O `--tor` prova o circuito antes (exit IP via check.torproject.org)
      pra falhar com a causa certa quando o daemon está fora.
      A COTA É O LIMITE DE VERDADE, e nenhum transporte muda: download anônimo tem ~5 GB
      por IP em janela DESLIZANTE de ~6 h, contada por IP e não por conta (logout não
      zera). O teste real foi um arquivo de 17,4 GiB = ~4 janelas. Por isso o laço
      distingue "over quota" (string do megatools) e ESPERA 30 min em vez de trocar de IP:
      janela deslizante libera aos poucos, então bater de 30 em 30 min rende mais que
      esperar 6h paradas — e fatiar o arquivo entre IPs diferentes é exatamente o que a
      cota existe pra impedir (é o que o megabasterd faz com lista de proxies). Pressa se
      resolve com conta Pro (`megadl -u/-p`, senha via sops), não com rotação.
      DETECÇÃO da cota por `case` em variável e NUNCA `| grep -q`: com o pipefail do
      writeShellApplication o grep sai no 1º match, o tail morre de SIGPIPE e o pipeline
      retorna erro APESAR do match (mesma pegadinha do healthcheck do Sunshine).
      E `du -shc` de glob que não casa nada JÁ imprime "0 total" **e** sai com erro — o
      `|| echo 0` do fallback saía somado ao dele, imprimindo "0" duas vezes na linha.
      RESULTADO MEDIDO (04/08, o arquivo de teste de 17,4 GiB): fechou PELO TOR em 3h19m,
      ~1,5 MB/s de média — bem acima do 709 KiB/s do instante inicial. E a cota NUNCA
      bateu, ao contrário do que eu previ: o Tor troca de circuito ao longo de horas
      (MaxCircuitDirtiness = 10 min pra stream nova) e o megadl abre conexão por chunk,
      então a saída passou por vários exit IPs sem ninguém pedir. Efeito colateral do
      desenho do Tor, não configuração daqui — e é por isso que a previsão "17 GB anônimo
      não sai" estava errada NESTE caminho; num IP fixo (direto/VPN única) ela vale.
      CONFERIR O ARQUIVO, e a ordem importa: (1) o megadl já verifica o MAC do MEGA e
      aborta com "MAC mismatch" — terminar sem erro é prova CRIPTOGRÁFICA de que os bytes
      são os do servidor, então isso vale mais que qualquer teste de arquivo depois;
      (2) `file` + assinatura em offset 0; (3) os 8 bytes finais, que num RAR5 completo
      terminam em `03 05 04 00` (header HEAD_ENDARC, tipo 5 = fim de arquivo) — é o que
      separa "download truncado" de "arquivo inteiro".
      ⚠️ PEGADINHA DO p7zip: `7z l` disse `Type = gzip` e "There are data after the end of
      archive" num RAR v5 PERFEITO. O p7zip do nixpkgs vem com `enableUnfree ? false` e o
      postFetch ARRANCA o código do unRAR — sem o codec ele não reconhece a assinatura,
      varre o arquivo e casa o primeiro blob parecido com gzip. Quase virou "o download
      corrompeu". Pra testar CRC de RAR de verdade: `nix shell nixpkgs#unrar -c unrar t`
      (unfree, e o allowUnfree deste repo já é true).
      VAZÃO MEDIDA (04/08) — o que era lento era o TOR, não o MEGA nem a linha:
        Hetzner (EUA): 1 stream 17,2 MB/s | 8 streams 42,2 | 16 streams 33,9 (piora)
        MEGA (gfs206n184): 1 stream 27,7 MB/s | 4 ranges paralelos 53,5 (449 Mbps)
        Tor (o download real): ~1,5 MB/s
      NIC é gigabit, então o teto é o plano (~450 Mbps). Os 17,4 GiB que levaram 3h19m
      pelo Tor sairiam em ~11 min num stream direto, ~5,5 min com 4 ranges.
      E É AQUI QUE VELOCIDADE E COTA SE OPÕEM: direto é 18× mais rápido e para nos ~5 GB
      da janela; o Tor é lento e na prática ilimitado (troca de circuito). Não existe
      "rápido E 17 GB" de graça — quem quer os dois usa conta Pro, e só então os ranges
      paralelos passam a valer (11 min → 5,5).
      POR ISSO NÃO CONSTRUÍ CLIENTE PARALELO: o ganho é 2× sobre o megadl sequencial em
      arquivo que já leva minutos, e custaria a API do MEGA + AES-CTR por chunk + o
      meta-MAC reimplementado à mão (o megadl já verifica de graça) — dívida nossa a cada
      mudança de protocolo do MEGA. Se um dia valer, o megabasterd faz multi-slot pronto,
      mas são 948 MiB de closure (arrasta JRE) medidos no cache.
      TOR SÓ PRA ARQUIVO PEQUENO: medi 709 KiB/s no circuito (3 saltos voluntários), o que
      daria ~7h e 17 GiB de banda DOADA num arquivo só; o projeto Tor desencoraja granel
      (a rede é dimensionada pra latência baixa, não pra vazão) e o MEGA ainda bloqueia
      parte dos exit nodes (falha imediata e repetida = exit bloqueado, não link ruim;
      circuito novo = `systemctl restart tor`).
- [ ] Salto de release 26.05 → 27.05 (~mai/2027) — NÃO é reinstalação: são DUAS STRINGS no
      flake.nix, `nixpkgs.url` (nixos-27.05) e `home-manager.url` (release-27.05), que mudam
      JUNTAS (o branch de release do HM casa com a base, senão dá mismatch de opções). Os
      outros ~9 inputs têm `inputs.nixpkgs.follows = "nixpkgs"` e vêm de graça — o dedup que
      já existe por causa do tamanho do lock é o que torna o salto trivial: 1 input muda, 9
      seguem. Sem ele, cada flake arrastaria seu próprio nixpkgs 26.05 e eu ficaria com duas
      bases coexistindo depois do salto.
      O `upgrade` NUNCA faz esse salto, e isso é feature: `nix flake update` só anda DENTRO do
      branch pinado, e no `nixos-26.05` entram só BACKPORTS — cherry-pick de CVE/bugfix que um
      mantenedor marca com a label `backport release-26.05`. Versão nova de pacote NÃO entra,
      exceto navegador e kernel (upstream só dá suporte de segurança à versão nova, então
      backportar patch de Firefox seria reescrever o Firefox). E `nixos-26.05` (canal) ≠
      `release-26.05` (branch): o canal é ponteiro que só avança depois do Hydra buildar e a
      suíte de testes passar — mesmo gating do nixos-unstable.
      ⚠️ O `stateVersion` NÃO MUDA — nem no salto, nem nunca. Fica "26.05" pra sempre em
      hosts/nixos-kingston/default.nix e home/default.nix. O nome engana: não é "a versão do
      meu sistema", é "a versão do NixOS com a qual o meu ESTADO EM DISCO é compatível". 54
      módulos do nixpkgs leem esse valor, e o caso canônico é o postgresql.nix, que escolhe o
      MAJOR do Postgres por ele (`versionAtLeast stateVersion "26.11"` → postgresql_18;
      "25.11" → postgresql_17 …). Bumpar faz o módulo apontar pra um major que NÃO LÊ o
      datadir existente: o
      serviço não sobe, e se algo reinicializar o cluster o banco foi. Rollback de geração não
      salva — volta o SISTEMA, não o /var/lib já mexido (mesma classe do dano do cutover, quando
      copiar /var/lib quebrou Docker/Postgres/Sunshine em silêncio). Por isso ele existe no
      config mesmo sendo imutável: é CERTIDÃO DE NASCIMENTO do estado, não botão — os módulos
      precisam saber quando o estado nasceu justamente porque não sabem migrá-lo sozinhos. Só
      muda se as release notes mandarem, e junto da migração manual (pg_upgrade e afins).
      Usar `nixos-rebuild boot` e NÃO `switch`: aplica no próximo boot e a geração 26.05 fica no
      minegrub como saída de emergência. E esperar ~2-4 semanas depois do release (o branch
      estabiliza conforme os backports chegam); o custo de esperar aqui é baixo, porque o que eu
      quero fresco já vem por `unstable.*` e pelos inputs upstream diretos.
- [ ] Deixar o VSCode de forma declarativa com o Nix e ao mesmo tempo sempre atualizar o sync com minha conta do GitHub/Microsoft (quero que fique centralizado no <https://github.com/v1cferr/dotfiles>)
- [ ] Adicionar o IP publico atual no Fastfetch?
