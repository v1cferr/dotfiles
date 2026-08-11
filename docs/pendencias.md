# Pendências

O que está em aberto. Item concluído migra para [historico/](historico/) —
este arquivo só cresce com trabalho novo, e encolhe quando trabalho termina.

Convenção herdada do arquivo único: cada item explica o QUE, o PORQUÊ e a
armadilha conhecida. Vale mais o parágrafo do que o título.

- [x] HEVC no Moonlight: TESTADO E DESCARTADO para o notebook da FAI (10/08/2026). Ligado às
      14:43 — negociou `hevc_vaapi` / Rec. 709 limpo, contra `h264_vaapi` / Rec. 601 — e o
      dono desligou às 14:57 por estar **"muito bugado"** na prática. **H.264 é a escolha
      final para esta máquina**, e é DELIBERADA, não default esquecido.
      • ⚠️ O MODO DE FALHA É O PIOR POSSÍVEL DE DIAGNOSTICAR, e é por isso que este item
        sobrevive fechado: do lado do HOST tudo parecia certo. O journal registrou
        `Creating encoder [hevc_vaapi]`, a colorimetria até MELHOROU (Rec. 601 → 709, que é
        correção de fato — 601 em conteúdo HD desloca cor), e mesmo assim a imagem entregue
        era ruim. O host codifica; quem decodifica é o cliente, e o host não enxerga isso.
        Negociação limpa não é sinônimo de reprodução boa.
      • ⚠️ ISSO DESMENTE A NOTA DE 03/08 em system/services/sunshine.nix PARA ESTE CLIENTE.
        Lá está escrito que ligar HEVC/AV1 "vale mais que qualquer ajuste deste arquivo" —
        e vale, onde o decode presta. Aqui não presta. Sem este registro, a próxima pessoa
        (ou eu) segue aquele conselho e perde a tarde de novo.
      • DUAS VOLTAS ERRADAS ANTES DE ACERTAR, e a lição é a mesma nas duas direções:
        1. fechei como "sem ação" por RELATO ("não tem GPU dedicada") — a medição desmentiu
           em 10 min, porque iGPU Intel decodifica HEVC desde ~2015;
        2. reabri como "funciona" por MEDIÇÃO DO HOST — o uso real desmentiu em 15 min.
        Nenhum dos dois instrumentos respondia a pergunta certa, que era "como fica a imagem
        no cliente". Só o olho de quem usa respondia.
      • O que sobra pra essa máquina: teto de bitrate e FEC, ambos no host.

- [ ] Peer `fai-workstation` (10.10.10.5) do WireGuard: vivo ou legado? (aberto em
      10/08/2026) — medido com o `wg-status` novo: em **17 dias** de uptime do roteador ele
      não fez UM handshake. E não é peer passivo esquecido: tem `persistent_keepalive = 25`,
      que existe justamente pra manter a conexão de pé.
      • As duas leituras possíveis, e elas pedem ações opostas: ou a workstation está com o
        WireGuard parado (e alguém conta com esse túnel sem saber que ele não sobe), ou o
        peer é resíduo e devia sair do roteador pela regra de zero legado.
      • ⚠️ NÃO APAGAR ANTES DE CONFERIR: o mount `~/FAI-workstation` (rclone SFTP) sobe junto
        com a VPN da FAI, não com este túnel — então o peer PARECE órfão sem ser. Conferir de
        lá com `wg` antes de decidir.
      • O peer `notebook` (.2) também está sem handshake, mas isso é ESPERADO e não é item:
        é exatamente o que o acesso direto de 10/08 substituiu.

- [~] TESTAR o Wake-on-LAN de verdade (aberto em 10/08/2026) — a config está aplicada e o
      `40-enp7s0.link` gerado com `WakeOnLan=magic`, mas NADA disso prova que a máquina
      acorda. Só desligar e mandar o pacote prova.
      • ⚠️ NÃO FECHAR ESTE ITEM SEM O TESTE. É o mesmo erro do HEVC de hoje, ao contrário:
        lá eu fechei por relato sem medir; aqui a tentação é fechar por config aplicada sem
        acionar. Config correta e efeito real são coisas diferentes — foi exatamente o que o
        fw4 ensinou hoje ao ACEITAR um `src_ip` em lista e DESCARTAR a seção.
      • ROTEIRO: `sudo poweroff` → do celular pelo WireGuard,
        `ssh v1cferr@192.168.1.1 'sudo wake-desktop'` → a máquina tem que ligar.
      • ESTADO ATUAL medido: `power/wakeup = disabled` e `Wake-on: d`. O `.link` só é aplicado
        pelo udev quando a interface APARECE, ou seja a partir do próximo boot. Armar antes
        disso, sem derrubar o link: `ethtool -s enp7s0 wol g`.
      • SE NÃO ACORDAR, o próximo suspeito é a BIOS: "Wake on LAN / Wake on PCIe" precisa
        estar ligado lá também. O SO arma a NIC; a placa-mãe decide se aceita o sinal.
      • ⚠️ ISTO NUNCA VAI COBRIR QUEDA DE ENERGIA, e não é falha do WoL: corte real tira o
        +5VSB e a NIC perde o registro armado. Pra "acabou a luz" quem responde é *Restore on
        AC Power Loss* na BIOS — e aí o WoL fica irrelevante, porque a máquina liga sozinha.

- [ ] MTU do túnel — medir e anotar (herdado do teste de 10/08/2026). Protocolo em
      [testes/wireguard-moonlight.md](testes/wireguard-moonlight.md).
      • Impossível testar de casa: não há interface WireGuard nesta máquina (o túnel termina
        no ROTEADOR), então ping pro 10.10.10.1 sai pelo cabo e mede a LAN. Sinal de teste
        inválido: latência de ~0,3 ms.
      • ⚠️ MUDOU DE VALOR EM 10/08/2026, e é preciso dizer por quê: este teste existia pra
        decidir se o `packet_size = 1024` podia subir. Não pode mais — com o caminho direto
        no ar, o valor é GLOBAL e serve DOIS caminhos de MTU diferente (túnel ~1420, direto
        1492), então o teto útil é o do menor. O número só volta a ser acionável se o túnel
        for aposentado. Medir mesmo assim vale: é o que diz QUAL dos dois é o menor.

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

- [ ] VS Code: o language server do `kamikillerto.vscode-colorize` aborta em loop
      (achado em 09/08/2026) — 15 coredumps em 2 dias, ~a cada 6-30 min de sessão. NÃO é
      o editor nem o nix: `coredumpctl info` entrega a linha de comando com o
      `.vscode/extensions/kamikillerto.vscode-colorize-0.17.1/server/out/server.js`.
      • Preço POR aborto, medido: 58 s de CPU, 2,6 GB de pico de RAM, 2,7 GB escritos no
        NVMe só pra gravar o dump. É a travada que se sente, e é desgaste de disco.
      • Conserto imediato = desabilitar a extensão (ou restringir `colorize.include`).
        Perde-se só o realce de cor. A extensão vem do Settings Sync, NÃO do nix — então
        o conserto é fora deste repo enquanto o item do VSCode declarativo não fechar.
      • ⚠️ NÃO é o mesmo bug do "stop job" de 90 s (que também acusava o VS Code): lá é o
        `app-code-*.scope` ignorando SIGTERM no desligamento; aqui é filho abortando no
        meio da sessão. Corrigir um não corrige o outro.

- [ ] SSOT pendente — só sobrou o HOME `/home/v1cferr` (5 arquivos: dolphin.nix, Theme.qml,
      restic.nix, fai-workstation-mount.nix, home/default.nix) → `my.user.home`. Prioridade BAIXA
      de propósito: ao contrário de fonte/cor/conector, o caminho não muda quando o hardware muda.

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

- [ ] Desligar todos os leds de todos os hardwares no modo AFK

- [ ] Instalar o driver/software do meu mouse Razer Deathadder v2 (adicionar a notificação de quando meu DPI mudar, etc)

- [~] Manutenção remota sem senha no roteador e no switch (OpenWrt).
      • ROTEADOR, feito: o SSH já era por chave (`ssh v1cferr@192.168.1.1` roda em BatchMode),
        e o que faltava era o `sudo`. Hoje são NOPASSWD `/sbin/reboot`, `/usr/sbin/nft`,
        `/sbin/uci`, `/etc/init.d/dnsmasq` e `/etc/init.d/firewall` (este entrou em
        10/08/2026 — justificativa e método no histórico).
      • DECISÃO A MANTER: comando arbitrário CONTINUA pedindo senha. Ampliar pra `(ALL)
        NOPASSWD: ALL` seria a mudança que de fato escala privilégio — as atuais não escalam
        porque o `nft` já dá o mesmo alcance. Só adicionar binário com motivo, um a um.
      • `/usr/bin/wg-status` entrou junto (wrapper só-leitura do `wg show`) — o binário `wg`
        inteiro NÃO entra, porque `wg set` troca chave de peer.
      • FALTA o SWITCH, que nunca foi tocado.
      • ⚠️ NADA DISSO É ESPELHADO: o `router-sync` cobre só `/etc/config/`. Sudoers e chave
        SSH vivem fora do repo, e o `/home/` do roteador nem sobrevive a `sysupgrade`.

- [ ] `ssh cesar` sem senha — instalar a chave pública no Windows do irmão (aberto em
      10/08/2026, junto do host declarativo em home/shell/ssh.nix). O `IdentityFile` já está
      declarado; falta só o lado de lá, que o Nix não alcança.
      • ⚠️ `ssh-copy-id` NÃO serve: ele assume shell POSIX, e o shell padrão do sshd do
        Windows é o cmd.exe. O passo é rodado NA máquina do irmão, em PowerShell.
      • ⚠️ RESOLVIDO QUAL ARQUIVO (medido em 10/08): o `v1cferr` lá é ADMINISTRADOR
        (`whoami /groups` traz BUILTIN\Administrators, SID S-1-5-32-544), e pra membro do
        grupo o sshd do Windows **ignora** o `~/.ssh/authorized_keys` — vale só o
        `C:\ProgramData\ssh\administrators_authorized_keys`, que ainda exige `icacls`
        tirando a herança. Sem isso o sshd recusa o arquivo e volta pra senha **sem dizer
        nada ao cliente** — o modo de falha é "não funcionou e não explicou".
      • Receita completa (as duas variantes) no comentário do bloco `cesar` em
        home/shell/ssh.nix.

- [ ] Configurar ambos os perfils do Claude (fai.ufscar.br) e do César (imagino que essa configuração esteja no meu backup da home no Google Drive que configuramos antes)

- [ ] Continuar configurando o dualboot com Secure Boot

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
