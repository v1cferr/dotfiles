# Histórico — agosto de 2026

57 entradas. Índice em [README.md](../README.md).

- [x] Hover no pill da VPN mostra qualidade do túnel (14/08/2026) — o pill respondia só
      "tem túnel?"; faltava "e está bom?", que é a pergunta de quem está com SSH ou chamada
      dependendo dele. Agora o HOVER abre `bar/VpnStatsPopover.qml` (latência, jitter,
      perda, gráfico da série, tráfego da sessão, tempo no ar) e o CLIQUE segue abrindo o
      `VpnPopover` de sempre, com conectar/desconectar. Informação no hover, AÇÃO no clique.
      • DIVISÃO DE TRABALHO: o `vpn stats-json` (novo) entrega o ESTADO — iface, IP, MTU,
        tempo no ar, bytes da sessão e QUAL host serve de alvo de sonda — e a barra MEDE a
        latência com ping contínuo. Não virou campo do `status-json` porque aquele é o
        polling de 5s que pinta o pill e tem de ser barato; este só roda com túnel de pé.
        Descobrir alvo (varrer rota, testar candidato, memorizar) é trabalho de shell;
        observar o tempo todo é trabalho de quem fica aberto.
      • ⚠️ O ALVO ÓBVIO DA SONDA NÃO SERVE: o peer do ppp da FAI é `192.0.2.1`, que é
        TEST-NET-1 — endereço de fachada do SonicWall — e ignora ICMP (MEDIDO: 100% de
        perda). Quem responde é `200.136.209.236` (fai.ufscar.br): IP público, mas a rota
        `200.136.209.128/25` sai pelo ppp0, então o ping mede o TÚNEL. Baseline medida a 1
        pacote/s: média ~34ms, mdev 0,8ms, 0% de perda — é dela que saem os cortes do
        veredito (estável / lenta / instável / ruim).
      • O `ping -I <iface>` não é detalhe de estilo: prende o pacote ao túnel
        (SO_BINDTODEVICE). Sem ele, um alvo que deixasse de ser roteado pela VPN sairia pela
        internet de casa e o painel exibiria uma latência ÓTIMA que não é a do túnel. Número
        errado é pior que número ausente — com o bind, esse caso vira "sem sonda". PROVA
        medida: o mesmo alvo preso ao `enp7s0` dá 100% de perda, então o número exibido não
        tem como vir de fora do túnel.
      • ⚠️⚠️ A 1ª VERSÃO MEDIA POR RAJADA E OS NÚMEROS ERAM BONITOS E FALSOS — o painel já
        estava pronto e aprovado ("está tudo certo") quando a pergunta "esses números são
        confiáveis?" derrubou metade dele. Ele pingava 3 pacotes a cada 20s. MEDIDO lado a
        lado na mesma hora: a rajada dava mdev **0,4ms**; uma janela de 20s dava mdev
        **3,3ms e pico de 54,7ms**. Ou seja, observava 0,6s de cada 20s (3% do tempo), então
        engasgo de 2s era invisível em 97% dos casos — e a perda, com 3 pacotes, tinha
        RESOLUÇÃO DE 33%: 1-3% de perda real aparecia como "0%". Só a média sobreviveu à
        auditoria (33,6 contra 34,4 da referência de 40 pacotes). Lição: amostra curta não
        responde pergunta sobre ESTABILIDADE, e um painel que exibe jitter de meio segundo
        com cara de vigilância mente por omissão de escala.
      • A CORREÇÃO foi virar sonda CONTÍNUA de 1 pacote/s (componente VpnProbe, no
        `Bar.qml`) com estatística sobre a janela dos últimos 60 pacotes: jitter de verdade,
        perda com resolução de 1,7% e uma barra por segundo no gráfico. Custo medido: 84 B/s,
        e 30 pacotes a 1/s deram 0% de perda — o alvo não faz rate-limit nessa cadência.
        O `-O` do ping é OBRIGATÓRIO: sem ele, pacote perdido é SILÊNCIO e a série ficaria só
        com os que voltaram — perda 0% eterna, o mesmo tipo de mentira de novo.
      • O `ping` é line-buffered mesmo escrevendo em pipe (verificado: uma linha por segundo,
        sem `stdbuf`), que é o que torna a leitura do fluxo viável.
      • WATCHDOG, porque sonda morta é a pior falha possível AQUI: com o `-O` o ping fala a
        cada segundo mesmo quando o alvo some, então SILÊNCIO não é perda de pacote — é o
        processo quebrado. Sem watchdog o painel congelaria exibindo a última janela boa,
        com cara de "estável", que é a mentira que ele existe pra não contar. 5s sem linha =
        marca o buraco na série e ressuscita o ping. TESTADO matando a sonda: voltou em 10s.
      • O TÚNEL CAIU E VOLTOU no meio do trabalho, e ensinou duas coisas. (1) O `ping -I` NÃO
        morre no reconnect: o ppp0 volta a se chamar ppp0 e o bind re-resolve — verificado
        pelo `wchar` do processo, que seguiu crescendo ~1 linha/s. (2) Justamente por isso a
        série emendaria dois túneis diferentes como se fossem um; o IP entrou na chave da
        sonda (mudou de 192.168.50.2 p/ .3) pra forçar série nova.
      • ⚠️ Pra VALIDAR mudança de QML aqui, `qs-restart`: o hot-reload manteve VIVO um Timer
        da árvore antiga (um `console.log` de depuração continuou saindo depois de o arquivo
        já estar limpo e de o log dizer "Configuration Loaded"). O quickshell.nix já avisa
        que o hot-reload não reaplica tudo — vale pra objeto com Timer/Process, não só pra
        delegate de Repeater.
      • O GRÁFICO existe porque "está estável?" é pergunta sobre o TEMPO: um "34 ms" sozinho
        não distingue túnel liso de túnel que oscilou 30→900ms no último minuto. A escala
        começa em ZERO (teto = 60ms, ou 15% acima do pico) — auto-escalar pelo mínimo faria
        0,5ms de variação virar serrote dramático, o oposto da leitura honesta.
      • Duas pegadinhas de QML, as duas de sintoma mudo: `readonly property real top` no
        delegate morre com "Cannot override FINAL property" (o nome colide com herança do
        Item) — virou `scaleTop`; e INLINE COMPONENT NÃO ENXERGA O `id` DO DOCUMENTO que o
        declara, então o `root.vpnStats[...]` dentro do VpnProbe estourava em ReferenceError,
        a instância não nascia, e quem reclamava era o POPOVER — `undefined` a três arquivos
        de distância da causa. O dado passou a CHEGAR por propriedade.
      • Alvo memorizado em `$XDG_RUNTIME_DIR/vpn-probe-<id>`, com chave iface+IP: túnel novo
        = sonda nova, e "não achei" é reavaliado a cada 5 min (senão um alvo fora do ar no
        instante da conexão condenaria o painel a "sem sonda" até desconectar).
      • O painel nasceu com 300px e o rodapé cortava o IP da sonda ("200.136.209…"). Foi p/
        360 com rodapé em duas linhas: painel de diagnóstico que elide dado é contraditório —
        quem abre está justamente atrás do detalhe.

- [x] Azure MCP Server, e SÓ na conta da FAI (14/08/2026) — o pedido era mexer no
      portal.azure.com por comando em vez de clicar na interface. Virou `pkgs/azure-mcp.nix`
      (o binário `azmcp`) + um campo `mcp` no `profiles` do `home/shell/claude-code.nix`.
      • POR QUE EMPACOTAR em vez de seguir a receita da Microsoft: a doc manda
        `npx -y @azure/mcp@latest server start`, que a regra 13 proíbe duas vezes — "latest"
        implícito E fetch sem hash A CADA START do servidor, ou seja o MCP podia trocar de
        versão no meio de uma sessão. O `@azure/mcp` do npm é só um shim JS que escolhe, no
        postinstall, um dos seis `@azure/mcp-<os>-<arch>`; quem tem o server é o pacote da
        plataforma, e dentro dele vem UM binário .NET self-contained de 150 MB. Então
        buscamos o tarball da plataforma direto e o `nodejs` sai inteiro do closure.
      • ⚠️ O ACHADO QUE CUSTOU AS DUAS PRIMEIRAS TENTATIVAS — `runtimeDependencies` (RPATH)
        NÃO resolve as libs deste binário, e o erro não diz por quê. Sem nada:
        `Couldn't find a valid ICU package`. Com icu+openssl no RPATH: ICU passa e vem
        `No usable version of libssl was found` + core dump. O motivo é que ele é
        single-file e DESEMPACOTA as libs nativas do .NET em `~/.net/azmcp/<hash>/` no
        primeiro start (o `libpal_azure_c_shared_openssl3.so` está lá) — é esse .so
        extraído, fora da store e sem RUNPATH nosso, quem faz o dlopen. LD_LIBRARY_PATH via
        `makeBinaryWrapper` é herdado pelas libs extraídas e resolve; e `makeBinaryWrapper`
        (execv em C) e não wrapper de shell, porque o .NET acha o `Instrumentation/Resources`
        por /proc/self/exe, que só fica certo DEPOIS do exec.
      • O `azure-cli` NÃO É NECESSÁRIO PRO LOGIN, e isso vale registrar mesmo tendo ele
        entrado depois por outro motivo (o item seguinte): a doc da Microsoft e a própria
        mensagem de erro do azmcp mandam instalá-lo, mas a cadeia do DefaultAzureCredential
        termina em DeviceCodeCredential — o "abra login.microsoft.com/device e digite
        ABC123" — que funciona sozinho. Ele só estava falhando com `Persistence check
        failed`, que NÃO é credencial: é o cache de token do MSAL tentando falar com o
        Secret Service. Faltavam `libsecret` e `dbus`, que esta máquina já tem pelo keyring.
        Com as duas na LD_LIBRARY_PATH o device code saiu na hora (verificado: código
        emitido, sem login). O `msalruntime`/libX11 do log de erro são o broker WAM, que só
        existe no Windows — ignorar.
      • ⚠️⚠️ E AÍ VEIO A CORREÇÃO QUE DERRUBOU A PREMISSA — o Azure MCP Server NÃO COBRE
        APP REGISTRATION, que era o motivo REAL de tudo isto ("não quero mais mexer naquela
        interface"). Eu tinha entregado o MCP sem checar se ele fazia a única coisa pedida.
        MEDIDO no `tools/list`: nas 68 tools não existe App Registration, service principal
        nem Graph; o `role` é RBAC de RECURSO do Azure, não app do Entra; e o
        `extension_cli_generate` só GERA o texto do comando `az`, nunca executa. A Microsoft
        também não publica MCP de Entra — o `microsoft/mcp` tem só Azure, Fabric e um
        template. O `entra-app-registration` do `microsoft/azure-skills`, que parecia ser a
        peça que faltava, é uma SKILL (markdown de orientação) e não uma tool: o que ela
        ensina o agente a fazer é rodar `az ad app create/list/show/permission add/…`.
        Ou seja, quem faz o trabalho é o `azure-cli`. Ele entrou (home/packages.nix), e o
        custo é 0,95 GiB MARGINAIS e não os 1,19 do closure — 0,24 já estava no sistema.
        LIÇÃO, e é sobre método, não sobre Azure: "a ferramenta oficial pro serviço X" não
        implica "cobre a parte de X que você quer". A lista de tools é barata de ler
        (handshake JSON-RPC no stdio) e devia ter vindo ANTES do pacote, não depois.
      • POR QUE O MCP É POR CONTA e não global: a nuvem é a do trabalho, e são 68 tools em
        `--mode namespace` (contadas por handshake JSON-RPC direto no binário) que não têm o
        que fazer na conta pessoal. Então `profiles.fai.mcp = [ azureMcp ]` e
        `profiles.pessoal.mcp = [ ]` — a conta que não declara não ganha a flag.
      • ⚠️ ARMADILHA DO `--mcp-config`, medida no CC 2.1.222 e a regra é o OPOSTO da
        intuição: a flag é VARIÁDICA, então engole tudo até achar um token começando com
        "-". Sem terminador, `claude-fai mcp list` morre com
        `MCP config file not found: …/mcp` (leu `mcp` e `list` como mais dois arquivos). Mas
        o `--` conserta SÓ o subcomando e ESTRAGA a flag: com ele, `claude-fai --version`
        abre uma sessão com "--version" de prompt. Daí o `case` no wrapper — começa com "-"
        (ou vazio) vai sem `--`; palavra solta vai com.
      • TRÊS CAMINHOS RECUSADOS: (1) `.mcp.json` da raiz, que é onde vivem os dois MCP da
        Cloudflare — é escopo de PROJETO, o Azure só existiria rodando `claude` dentro do
        dotfiles, que é justamente onde nunca vamos mexer no Azure; (2) user scope no
        `.claude.json` — estado do app, o CC reescreve o arquivo inteiro (regra 14);
        (3) `/etc/claude-code/managed-mcp.json`, que PARECE o lugar certo por ser irmão do
        managed-settings.json dos hooks, e é armadilha: quem deploya esse arquivo ganha
        controle EXCLUSIVO e o CC para de carregar todo o resto, inclusive os MCP dos
        plugins `github` e `atlassian`, que estão em uso. Ganharia um e perderia dois.
      • DE QUEBRA, TRÊS ARESTAS DO MÓDULO: o `claude` puro virou wrapper (era o binário cru,
        e sem isso o MCP não chegaria na extensão do VS Code, que chama o binário do PATH);
        o `.claude-fai` que estava escrito duas vezes virou `defaultProfile` (regra 11); e o
        `claude-pick` parou de repetir a lógica do CLAUDE_CONFIG_DIR — agora o menu carrega
        o CAMINHO DO WRAPPER e ele só dá `exec`, então herda MCP e variável de graça.
      • ⚠️ O LOGIN TEM DUAS ARMADILHAS, e as duas MENTEM sobre o que aconteceu. A primeira:
        `az login` puro, numa conta cujo tenant não tem subscription, termina em
        `No subscriptions found` — e NÃO PERSISTE NADA. A autenticação passou; foi o `az`
        que abortou depois, e o `az account list` seguinte diz "Please run az login", que
        lê como "sua senha falhou". O certo é `az login --allow-no-subscriptions --tenant
        <id>`, e não é caso de canto: App Registration é objeto de DIRETÓRIO, então o
        tenant de trabalho aqui legitimamente não tem assinatura nenhuma. A segunda:
        `az ad app list` sozinho não lista nada — exige um seletor (`--show-mine` pros que
        você é owner, `--all` pro tenant inteiro, que aí pede papel de admin no Entra).
      • DUAS IDENTIDADES, com papéis OPOSTOS, e isso decide qual ferramenta serve pra quê:
        `FAIUFSCar` (80241bb1-cb3b-4da2-98ae-3029430fdbcd) é só diretório — é onde vivem os
        App Registrations, e é o alvo do `az ad`; `BHS` (92247c24-8a8c-47f3-a7f1-85df939ad4b6)
        é quem tem subscription, e exige MFA (`AADSTS50076` — configuração do tenant, não
        defeito daqui). Ou seja: App Registration = `az ad` no FAIUFSCar; as 68 tools do
        MCP, que operam sobre subscription, só têm o que fazer no BHS.
      • VALIDADO PONTA A PONTA: `nixos-rebuild build` OK; servidor sobe (`initialize` +
        `tools/list` por JSON-RPC no stdio); `system/init` de uma sessão headless lista
        `{"name":"azure","status":"connected"}` ao lado dos plugins; `az ad app list
        --show-mine` devolveu os 3 apps do tenant; e o `azmcp subscription list` passou a
        responder `status 200` com `subscriptions: []` em vez de 401 — o que prova que o
        AzureCliCredential fecha a cadeia e o device code virou plano B, não o caminho.

- [x] Curva do hyprsunset desce de novo pós-18h (13/08/2026) — a pergunta que abriu isto era
      outra: "o hyprsunset está iniciando junto com o PC? porque não parece". **Não havia
      defeito nenhum no autostart**, e o motivo de "não parecer" é a própria config.
      • A MEDIÇÃO QUE DESMENTIU O SINTOMA: boot às 11:58:58, serviço ativo às 11:59:05 — 7 s
        depois — e a PRIMEIRA coisa que ele fez foi `Applying profile from: 8:0` →
        `Resetting the matrix (--identity passed)`. Ou seja, ligou e aplicou o filtro
        DESLIGADO, porque das 8h às 17:30 o perfil é `identity`. Nada visível no boot era o
        comportamento CORRETO. Serviço `enabled`, 8 h de pé, 234 ms de CPU, zero restart.
      • ⚠️ ARMADILHA GERAL, que vale além deste serviço: uma automação cujo estado correto é
        "sem efeito visível" NÃO se audita pelo olho. Passei perto de tratar percepção como
        evidência de falha; o que fechou a questão foi o journal (`Switched to new profile`
        de hora em hora: 17:30 → 5500K … 20:00 → 3200K) mais o `hyprctl hyprsunset
        temperature` batendo com o perfil do relógio.
      • O CTM CHEGA NAS DUAS TELAS, e isso foi VERIFICADO, não presumido: A/B por IPC
        (`identity` → 3000K → volta ao perfil) com o dono olhando. Mudou em DP-2 e na LG TV
        do HDMI. Importava confirmar antes de mexer na curva — se uma saída não recebesse o
        CTM, nenhum ajuste de Kelvin resolveria, e o histórico de 08/08 já registra que o
        hyprsunset aplica em TODAS as saídas ou em nenhuma (não sabe mirar output).
      • A MUDANÇA, então, é de PREFERÊNCIA e não de correção: cada degrau pós-18h desceu
        ~200–400K (18h 4200→3800, 19h 3500→3200, 20h 3200→3000, 22h 2800→2600, 23h
        2500→2400). Seguem 13 perfis e o maior degrau segue às 18h (agora 5000→3800).
      • ⚠️ ESCOLHIDO O EIXO DA COR CONTRA O QUE ideias.md RECOMENDA. Lá está registrado que
        reduzir BRILHO vem antes de temperatura de cor, e que "modo noturno não substitui
        brilho adequado" — a curva pós-18h continua mexendo só em Kelvin, com gamma
        entrando só às 22h. Foi escolha consciente do dono depois de ver as duas propostas
        lado a lado, não descuido: o dim automático por gamma existiu e foi REVERTIDO em
        08/08 junto com o DDC, e reintroduzi-lo é mudança maior que baixar Kelvin.
      • O QUE FICA EM ABERTO e está anotado no cabeçalho do módulo: se esta curva não
        bastar, o próximo passo é gamma progressivo a partir das 18h — **não** continuar
        descendo Kelvin, que daqui pra baixo piora a cor sem alívio proporcional.
      • O PREÇO ACEITO: a curva agora atravessa os ~3200K de propósito, e o cabeçalho do
        `hyprsunset.nix` avisava que abaixo disso a cor estraga filme/jogo/foto. Das 19h em
        diante isso passa a ser o NORMAL, então SUPER+SHIFT+F9 (`identity`) deixa de ser
        escape hatch raro e vira gesto rotineiro pra abrir mídia à noite. O próximo perfil
        do relógio retoma a curva sozinho.

- [x] `/mnt/arch-antigo` montado SEMPRE, e o `arch-browse` morreu (11/08/2026) — o sintoma
      foi abrir o bookmark no Dolphin e ver pasta vazia. Não havia defeito: segredos
      legíveis, repo respondendo, mount subindo em ~20 s quando pedido. O defeito era o
      DESENHO — automação sem dono declarado (regra 15), viva só enquanto o terminal do
      alias ficasse aberto. Virou serviço: `home/services/arch-antigo-mount.nix` (a unit
      que monta) + `system/services/arch-antigo.nix` (mountpoint e SSOT do caminho, que o
      bookmark passou a ler — regra 11).
      • POR QUE DOIS ARQUIVOS, e não é preciosismo de regra 4: quem MONTA tem que ser o
        usuário (mount FUSE é privado de quem montou; `sudo restic mount` gera pasta que o
        Dolphin não abre), mas quem CRIA o diretório tem que ser root, porque /mnt é dele.
        E a opção nasce do lado sistema porque módulo de sistema não lê opção do
        home-manager — o contrário não existe.
      • O diretório saiu do `restic.nix`, onde era criado junto do /mnt/backup. Lá ele
        ficava atado ao toggle `restic`: desligar o backup passaria a derrubar um mount
        agora PERMANENTE, e a falha apareceria longe da causa.
      • ⚠️ `--no-lock`, e isto foi MEDIDO, não economizado: todo `restic mount` cria lock
        não-exclusivo e o renova a cada ~5 min, e mount que não sai limpo deixa o lock
        PRESO. O repo tinha 3 locks — um do mount vivo e restos de `arch-browse` de 05/08 e
        08/08. Permanente, isso só pioraria, e ainda escreveria no repo offsite a cada 5 min
        pra sempre. O lock protege leitura concorrente com PODA, e este repo é estático:
        nada escreve nele desde 01/08 e nenhuma rotina o poda (o `forget --prune` só olha o
        repo HOME). Conferido depois: mount de pé, 0 locks.
      • ⚠️ O `Type = "notify"` do ~/Drive NÃO dá pra copiar: `restic mount` não fala
        sd_notify (não há "notify" no `--help` da 0.18.1). Com Type=simple o systemd daria a
        unit por pronta antes do mountpoint existir — reproduzindo o sintoma que a mudança
        veio matar. Por isso o ExecStartPost que espera o `mountpoint -q` (writeShellApplication,
        regra 7), com TimeoutStartSec=180 pra a espera caber.
      • O binário do rclone vai PINADO em `-o rclone.program=`: o backend `rclone:` EXECUTA
        o rclone e unit de systemd não herda PATH — mesma pegadinha que já matou o serviço
        de backup ("executable file not found in $PATH"), resolvida sem depender de PATH.
        E o rclone.conf é CÓPIA GRAVÁVEL em `%t`, arquivo próprio (não o do ~/Drive): sem
        isso o token OAuth renovado gera `Failed to save config` no journal — num serviço
        24/7, ERROR recorrente escondendo erro de verdade.
      • O PREÇO, medido: ~195 MiB de RSS residentes (115 do restic com o índice do snapshot
        de 44,6 GiB + 79 do `rclone serve restic`). Em rede, parado, é ZERO — o restic não
        faz polling. O comentário do bookmark dizia que mount permanente seria "conexão
        aberta e lock no repo por nada": a conexão é real e virou escolha consciente, o lock
        deixou de existir. E o aviso das miniaturas do Dolphin ficou MAIS importante, não
        menos — preview lê conteúdo, cada leitura baixa packs, e agora a pasta está sempre a
        um clique.
      • Pasta vazia ali deixou de ser estado normal e virou SINTOMA: o diagnóstico começa em
        `systemctl --user status arch-antigo-mount`.

- [x] O `switch` que ativou mas não virou boot, por causa de uma unit ALHEIA (11/08/2026) —
      o `rebuild` do mount acima terminou com `Activation (test) failed` (exit 4) e a
      culpada era a `vpn-fai`, que não tinha relação nenhuma com a mudança: já repicava
      antes (contador de restart em 43) porque o servidor da FAI responde
      `"Password change needed"` — senha institucional expirada. O `nh` roda a ativação em
      `test` ANTES de fixar a geração, e abortou a fase `boot`.
      • ⚠️ O ESTRAGO É SILENCIOSO e não aparece na hora: `/run/current-system` já era a
        geração nova (tudo funcionando na sessão), mas `/nix/var/nix/profiles/system` ficou
        na ANTIGA — ou seja, o próximo boot voltaria pro sistema sem a mudança. Quem não
        compara os dois não vê. Diagnóstico de um comando:
        `readlink -f /run/current-system /nix/var/nix/profiles/system` — iguais = fechou.
      • A LIÇÃO, que é maior que este caso: uma unit falhando por motivo EXTERNO (senha
        expirada, serviço remoto fora) sequestra o switch inteiro. `systemctl stop` nela e
        rebuildar de novo resolveu — a `vpn-fai` é `linked` sem `WantedBy`, então parar não
        perde nada, ela não sobe no boot mesmo.
      • Pendente do lado da FAI: trocar a senha no portal e atualizar `fai_vpn_password` no
        sops (alimenta o template `nxbender-fai.conf`, `system/net/vpn.nix`) + rebuild. Até
        lá, `~/FAI-workstation` e `ssh workstation` seguem fora.

- [x] `claude-fai` / `claude-pessoal`: DUAS contas do Claude Code, e o `~/.claude` deixou de
      ser uma delas (11/08/2026) — no Arch isso eram dois aliases e uma função de shell no
      `~/.zshrc` (`_claude_share_projects`), rodando a cada abertura de terminal. Virou
      `home/shell/claude-code.nix`: uma atriz `profiles` que é SSOT das contas e gera tudo —
      wrappers, menu do `claude-pick`, symlink de `settings.json` e symlink de `projects/`.
      Conta nova = uma entrada nela + um `settings-<nome>.json`.
      • ⚠️ ERREI NA PRIMEIRA VERSÃO, e o erro é instrutivo: criei um `~/.claude-fai` VAZIO
        ao lado do `~/.claude` — que JÁ ERA a conta da FAI (`oauthAccount.emailAddress` =
        victor.ferreira@…, seat nonprofit premium). Seriam dois logins pra mesma assinatura,
        e a "terceira conta" existiria só por acidente de nomenclatura. Copiei a topologia do
        Arch (default + 2) sem conferir QUEM era cada pasta AQUI. Lição: em migração, a
        pergunta não é "quais pastas existiam lá", é "o que cada pasta É aqui" — e a resposta
        estava a um `jq .oauthAccount ~/.claude.json` de distância.
      • O `claude` PURO virou a FAI, via `home.sessionVariables.CLAUDE_CONFIG_DIR`. Pega tudo
        que chama o binário sem passar pelos wrappers: extensão do VS Code, script, cron.
        ⚠️ Só vale em shell NOVO (o hm-session-vars.sh é lido no início da sessão) — o
        terminal que rodou o `rebuild` segue no `~/.claude` até ser fechado. Mesma pegadinha
        do NH_FLAKE em 03/08, com a diferença de que aqui um terminal novo já resolve.
      • O `~/.claude` CONTINUA EXISTINDO, agora como ACERVO e não como conta: o `projects/`
        (200 MB, 13 projetos, 39 memórias deste repo) é da MÁQUINA, não de uma assinatura.
        Ficar no caminho canônico faz ferramenta de terceiro achar sozinha e evita que
        aposentar uma conta um dia órfã o acervo. Foram consideradas e recusadas: mover pra
        dentro do `.claude-fai` (assimétrico) e pra um caminho neutro (200 MB movidos com
        sessão viva escrevendo lá).
      • O QUE MIGROU do `~/.claude` pro `~/.claude-fai`, porque é a MESMA conta: os plugins
        instalados (8,1 MB — `github`/`atlassian`/`frontend-design`, que o
        `settings-fai.json` do repo passou a declarar em vez dos do Arch, senão a migração
        os desligaria em silêncio), o `settings.local.json` (permissões já aprovadas), o
        `.claude.json` SEM `oauthAccount`/`claudeCodeFirstTokenDate` (17 pastas confiáveis
        preservadas, campos de conta deixados pro `/login` reescrever) e o `history.jsonl`
        concatenado com o do Arch — 128 + 1705 linhas, e a concatenação é cronológica de
        graça porque as janelas não se sobrepõem (o Arch termina em junho, esta máquina
        começa em julho).
      • WRAPPER NO LUGAR DE ALIAS, e a diferença não é estética: alias só existe em zsh
        INTERATIVO, então no Arch `claude-fai` não funcionava por SSH não-interativo, dentro
        de script, em task do VS Code nem em keybind do Hyprland. Agora são binários gerados
        por `writeShellApplication` (regra 7: lógica no build), o que de graça FIXA a versão
        do `claude` chamado — e isso importa aqui, porque esta máquina tem uma instalação
        nativa órfã em `~/.local/bin` que o `claude doctor` reclama e que o PATH poderia
        resolver primeiro.
      • ⚠️ O QUE DECIDIU O DESENHO DO `settings.json`, e foi MEDIDO em vez de suposto: o
        arquivo é linkado pro repo por `mkOutOfStoreSymlink`, mesmo contrato do VS Code
        (home/apps/vscode.nix), e isso só é seguro se o CC não trocar o symlink por arquivo
        comum ao salvar. Ele escreve de forma ATÔMICA (tmp + rename), o que MATARIA o link —
        mas resolve o realpath ANTES: rodando `claude auto-mode reset` num perfil de teste, o
        symlink ficou intacto e quem trocou de inode foi o ALVO (593793 → 593844). Ou seja: o
        `/config` da TUI continua funcionando e cada ajuste cai como `git diff` em vez de
        drift invisível (regra 16). Se um dia o CC perder essa guarda, o sintoma é
        `~/.claude-fai/settings.json` deixar de ser symlink e o repo parar de receber.
      • ⚠️ NÃO apontar `CLAUDE_CONFIG_DIR` pro `~/.claude` pra "reaproveitar" a conta default:
        o `.claude.json` (config de projetos/MCP, distinta do `settings.json`) mora na RAIZ do
        `CLAUDE_CONFIG_DIR` — no default é o `~/.claude.json` do home, e com a variável
        apontada pro `~/.claude` ele viraria `~/.claude/.claude.json`, um SEGUNDO arquivo
        divergente. Verificado no 2.1.222, junto do resto: `claude mcp add` com o
        `.claude.json` symlinkado escreveu ATRAVÉS do link.
      • DUAS CONFIGS MORRERAM NA TRAVESSIA (regra 16) e é por isso que os `settings-*.json`
        não são cópia fiel do Arch: o `permissions.allow` com `mcp__pencil` e os dois MCP de
        usuário que estavam no `.claude.json` das duas contas — `pencil`
        (`/opt/pencil-dev-bin/…`, pacote do AUR que não existe no NixOS) e `atlassian` (por
        `npx mcp-remote`, hoje feito pelo PLUGIN `atlassian@claude-plugins-official`, que a
        conta default já usa). Migrar permissão pra MCP que não sobe é declarar o inexistente.
      • `projects/` SEGUE COMPARTILHADO, agora por symlink declarado: é onde ficam os
        transcripts E a memória por projeto (`…/projects/<slug>/memory/`), então qualquer
        conta resume as mesmas conversas e lê as mesmas memórias. Preço conhecido: o
        `ccusage` não separa custo por conta, porque lê o acervo comum — o número é o da
        máquina, não o da assinatura.
      • ESTADO VEIO DO RESTIC, NÃO DO REPO (regra 6): o `history.jsonl` das duas contas (128 e
        179 prompts) saiu do backup do Arch por `restic dump` — sem montar nada, que é o
        caminho melhor quando se quer arquivo específico e não navegar. O `.credentials.json`
        NÃO foi restaurado de propósito: token de 7 semanas de uma máquina desativada vale
        menos que um `/login` limpo, e credencial não se declara nem se copia por script
        (regras 6 e 12).
      • O shellcheck do `writeShellApplication` reprovou o primeiro build por SC2155
        (`export X="$(cmd)"` mascara o exit code do comando). Regra 7 se pagando no build em
        vez de num bug de runtime.

- [x] VT-x ligado na BIOS — e o passo seguinte que este histórico mandava dar NÃO
      é necessário (11/08/2026) — a entrada do Cowork (08/08) fechava com "ligar VT-x e SÓ
      ENTÃO somar `users.users.v1cferr.extraGroups = [ "kvm" ]`, que não entrou por não ser
      validável sem o device". O device existe agora, então dava pra validar — e a validação
      DESMENTIU o plano.
      • VT-x confirmado: `vmx` nas flags do `/proc/cpuinfo`, `kvm_intel` carregado,
        `/dev/kvm` criado às 07:11. Sumiram os `VMX (outside TXT) disabled by BIOS` do log.
      • ⚠️ O GRUPO `kvm` NÃO ENTRA: o `/dev/kvm` nasce em **modo 666** (regra udev que o
        NixOS já embarca), grupo `kvm`. Medido que o `v1cferr` tem leitura E escrita nele
        SEM estar no grupo. Somar o `extraGroups` seria declarar uma permissão que o
        sistema já dá a todo mundo — config morta pela regra 16, no mesmo dia em que a
        regra nasceu.
      • A LIÇÃO é sobre a forma da anotação, não sobre o kvm: "faça X e DEPOIS faça Y"
        registra uma HIPÓTESE sobre Y como se fosse plano. Quando X finalmente acontece,
        Y é executado sem ninguém reverificar se ainda faz sentido — e aqui não fazia.
        Anotação de passo futuro deveria carregar o TESTE que decide se ele é preciso
        (`test -w /dev/kvm`), não só a ação.
      • Secure Boot segue `Disabled` e isso NÃO regrediu: `Setup Mode: Disabled` diz que as
        chaves continuam enroladas, então permanece só a Fase 4 do guia — virar a chave.
      • De quebra, o diagnóstico do colorize se confirmou: **19 h sem um único aborto**
        (último em 10/08 18:30) contra um a cada 30–60 min antes. Os coredumps que ainda
        aparecem no `coredumpctl` são todos anteriores à remoção — registro, não atividade.

- [x] Coreutils GNU na máquina inteira do `cesar` — e não foi preciso instalar nada
      (11/08/2026). O Git for Windows já embarcava o userland completo (coreutils 8.32,
      grep 3.0, sed 4.9, awk, less, vim) em `C:\Program Files\Git\usr\bin`; ele só não
      estava exposto, porque o instalador do Git põe no PATH apenas o `Git\cmd`. A
      mudança foi UMA entrada no PATH de máquina.
      • **A decisão inteira está na ORDEM: apêndice no FIM, nunca no início.** Esse
        diretório traz `find.exe`, `sort.exe`, `tar.exe`, `link.exe` e `echo.exe`, todos
        com homônimo do Windows de semântica diferente. Prependar — que é o que o
        instalador do Git oferece como opção, com aviso — quebra script `.bat` e build
        MSVC, porque o `link.exe` do MSYS não é o linker da Microsoft. No fim, ganha-se
        tudo que não conflita e não se perde nada. AFERIDO com `where`: `find`/`sort`/
        `tar` continuam resolvendo pro System32, e `ls` resolve pro GNU porque só existe
        um.
      • ⚠️ NO POWERSHELL ISSO RENDE MENOS DO QUE PARECE, e não é problema de PATH:
        `ls`, `cat`, `cp`, `rm`, `sort`, `curl`, `echo` são ALIASES nativos, e alias
        vence PATH sempre. Lá é `ls.exe` na mão. No `cmd` não há aliases e funciona
        direto; dentro do bash a questão nem existe.
      • Aplicado por `powershell -EncodedCommand` (base64 UTF-16LE) em vez de aspas
        aninhadas: o comando atravessa zsh → ssh → cmd → powershell, e cada camada come
        um nível de quoting. Um `dir /b "C:\...\usr\bin" | find /c` chegou a reportar
        "path not found" num diretório que EXISTIA, só pelo mangling do cmd no pipe —
        quase virou "essa instalação do Git é mínima e não tem os utilitários".
      • O script é idempotente (`-split ";" -notcontains`), porque PATH de máquina é
        exatamente o tipo de coisa que se aplica duas vezes sem perceber.
      • **Nasceu o guia** [`docs/guias/cesar-windows-passos-manuais.md`](../../guias/cesar-windows-passos-manuais.md):
        chave autorizada, PATH, Scoop e Claude Code. São os passos que o Nix NÃO alcança
        (a máquina não é NixOS e não é nossa), e sem eles escritos a reinstalação do
        Windows viraria redescoberta do zero. Mesma natureza do `authorized_keys` do
        roteador OpenWrt.
      • VERIFICADO de quebra que o `SetEnv TERM` continua desnecessário: dentro do Git
        Bash o `TERM` já vem `xterm-256color`, definido pelo próprio shell. A decisão de
        10/08 de não mandar a variável se sustenta agora que o shell mudou.

- [x] `ssh cesar` — o PC do irmão virou host declarativo (10/08/2026). O acesso já
      funcionava à mão (`ssh v1cferr@192.168.1.40`); o que entrou em home/shell/ssh.nix foi o
      alias e, principalmente, o registro de POR QUE este host não se parece com nenhum dos
      outros três: ele é o único **Windows** do arquivo.
      • **Herdar `faiResilience` seria carga cultuada.** Aquele bloco existe pra tolerar o
        buraco de rota do túnel SonicWall dentro do orçamento de 17 s do VS Code Remote-SSH.
        Aqui é salto de LAN, <1ms — mesma decisão já tomada no `router`, e o padrão do
        arquivo passa a ser "resiliência é opt-in, não default".
      • **Sem `SetEnv TERM`, ao contrário dos outros três hosts.** O shell padrão do sshd do
        Windows é o **cmd.exe**, que não lê TERM, e o sshd de lá não traz `AcceptEnv` — a
        variável seria descartada no servidor. Copiar por simetria daria uma linha que não
        faz nada e que a próxima leitura ia tentar "consertar".
      • ⚠️ **O aviso de post-quantum a cada conexão NÃO é erro nosso.** O servidor é
        `OpenSSH_for_Windows_9.5` (medido no `-v`), e o `mlkem768x25519` só existe do OpenSSH
        9.9 em diante; o Windows 11 build 26200 ainda embarca o 9.5. Só some quando a MS
        atualizar o Win32-OpenSSH. RECUSADO calar com `WarnWeakCrypto = "no"` (existe no
        nosso 10.4): silenciar por host esconde a defasagem real do servidor, e o dia em que
        ela for corrigida passaria despercebido. O aviso é barulho honesto.
      • ⚠️ **`ssh-copy-id` NÃO funciona contra Windows** — ele assume shell POSIX do outro
        lado, e do outro lado tem cmd.exe. O passo manual é rodado NA máquina do irmão, e
        QUAL arquivo depende de o usuário ser administrador: se for, o sshd do Windows
        **ignora** o `~/.ssh/authorized_keys` dele e só lê
        `C:\ProgramData\ssh\administrators_authorized_keys` — que ainda exige `icacls`
        restringindo a herança, senão o sshd recusa o arquivo e volta pra senha **em
        silêncio do lado do cliente**. FEITO no mesmo dia, e validado com
        `ssh -o BatchMode=yes ... "echo OK"` — o `BatchMode` proíbe o prompt de senha, então
        o `OK` prova que foi a CHAVE que autenticou; sem ele o teste é ambíguo, porque você
        digita a senha e conclui que a chave funcionou.
      • ⚠️ `Add-Content -Encoding ascii` não é preciosismo: o padrão do PowerShell pra
        arquivo é UTF-16, e o sshd não lê `authorized_keys` em UTF-16 — falha MUDA, cai na
        senha sem dizer por quê. Mesma classe de armadilha do `icacls`: as duas formas de
        errar aqui são silenciosas e indistinguíveis uma da outra.
      • SENHA da conta trocada junto, e a decisão foi MEDIDA antes: o Windows distingue
        TROCAR senha (com a antiga em mãos, que re-embrulha a chave-mestra do DPAPI) de
        RESETAR (`net user v1cferr *`, que a torna irrecuperável e leva junto Credential
        Manager, senhas de navegador e EFS — tudo em silêncio). Não há caminho de "troca"
        por linha de comando sem P/Invoke, e por SSH não existe Ctrl+Alt+Del. O reset foi
        seguro porque `cmdkey /list` veio `* NONE *` (nada a perder) e o
        `Get-LocalUser | Select PrincipalSource` veio `Local` — se viesse `MicrosoftAccount`,
        nem `net user` nem `Set-LocalUser` mudariam nada, porque a senha seria da conta MS.
      • IP literal (192.168.1.40) e não opção `my.*`: citado num lugar só, mesma
        justificativa do `router` — literal solitário não dispara a regra 11. Mas é DHCP: se
        o roteador entregar outro endereço, o alias quebra, e o conserto é reserva de DHCP
        no OpenWrt, não mais uma opção aqui.
      • **O shell virou GIT BASH, e o bash já estava lá o tempo todo.** `RequestTTY` +
        `RemoteCommand` apontando pro `C:\Program Files\Git\bin\bash.exe` — testado, cai em
        `v1cferr@Cesar MINGW64 ~$`. ⚠️ O `where bash` MENTE nessa máquina: o único `bash` no
        PATH é `C:\Windows\System32\bash.exe`, que **não é bash** — é o stub legado do WSL, e
        não há distro instalada. O bash de verdade não aparece no `where` porque só o
        `Git\cmd` está no PATH e o binário mora no `Git\bin`. Quase virou "essa máquina não
        tem bash", quando tinha.
      • **E com ele vieram os coreutils, sem instalar nada.** O Git for Windows embarca o
        userland GNU inteiro (`ls`, `grep`, `sed`, `awk`, `find`, `less`, `tar`, `curl`…) — a
        queixa de "faltam coreutils" era, na verdade, a queixa de cair no cmd.exe.
      • RECUSADO trocar o shell pelo registro (`HKLM:\SOFTWARE\OpenSSH\DefaultShell`): é
        GLOBAL, mudaria o shell de toda sessão SSH da máquina, inclusive a do dono. Do lado
        do cliente a escolha é só nossa e some junto com este repo.
      • RECUSADO instalar WSL, mesmo com o `v1cferr` sendo admin: o projeto do irmão é
        Gradle/Java Windows-native (`gradlew.bat`), e rodá-lo do WSL contra `/mnt/c` cruza a
        fronteira de I/O que é justamente onde o WSL é lento — fora plantar GB de VM na
        máquina dos outros. O CUSTO ASSUMIDO: o sandboxing do Claude Code só existe no WSL2,
        então no Windows nativo a permissão é a única barreira.
      • ⚠️ `RemoteCommand` e comando de linha são MUTUAMENTE EXCLUDENTES no ssh ("Cannot
        execute command-line and remote command"), então o bloco de cima sozinho QUEBRARIA
        `scp`, `rsync` e `ssh cesar <cmd>`. Daí o gêmeo `cesar-cmd`, mesmo host sem
        `RemoteCommand`: `cesar` pra sentar e trabalhar, `cesar-cmd` pra copiar arquivo. A
        alternativa era decorar `-o RemoteCommand=none` em toda invocação.

- [x] Auditoria de crescimento em disco: o Docker era o único sem teto, e o btrfs/GC
      não precisavam de nada (10/08/2026) — a pergunta era "o btrfs está bem? tem swap? o
      GC limpa direito?". As três respostas foram "sim, não mexa", e o problema real estava
      num quarto lugar que ninguém tinha olhado.
      • 🟠 **Docker: 11,35 GB de build cache, 8,5 GB recuperáveis, ZERO política.** Todos
        os vizinhos já tinham teto — journald em `SystemMaxUse=2G`, coredump vacuado pelo
        systemd, btrbk com `snapshot_preserve`, nix com `gc` semanal. O Docker era o único
        sem nada, e o `grad-radar.nix` que entrou na véspera PIOROU isso: ele roda
        `docker compose build` no ExecStartPre, a cada boot. Resolvido em
        system/services/docker.nix; a poda manual recuperou 8,501 GB (cache 11,35 → 2,85).
      • DUAS OPÇÕES RECUSADAS, e as duas destroem dado na MESMA janela — o stack PARADO
        na hora da poda semanal. Nenhuma dá erro; elas apagam com sucesso o que não devem.
        `allVolumes.enable` poda volume NOMEADO, e é onde vivem `duo_duo-db-data` e
        `grad-radar_db_data`: com o compose derrubado, a poda apagaria os dois Postgres.
        `flags = ["--all"]` remove imagem COM TAG sem container rodando, e as imagens
        locais não vêm de registry — some = rebuild, que no grad-radar inclui
        `pnpm install` dentro do container (a unit tem `TimeoutStartSec = 1800` por isso).
        O `--all` é o que a maioria dos configs públicos usa; aqui não paga.
      • ⚠️ O `weekly` do systemd é **Mon 00:00**, que é exatamente o minuto do `nix-gc`.
        Ficou `Mon 04:30`, depois do restic (03:00 + até 30 min) e do nix-optimise (03:45).
        Duas faxinas pesadas de I/O na mesma NVMe no mesmo minuto não ganham em coincidir.
      • **btrfs: nada a fazer — e um conselho popular a NÃO seguir.** As opções montadas
        são `noatime,compress=zstd:1,ssd,discard=async,space_cache=v2`, que é o conjunto
        correto. NÃO adicionar `fstrim.timer`: o `discard=async` já é TRIM contínuo, e o
        timer não está habilitado justamente por isso. Alocação sadia com ~398 GiB não
        alocados (Data 548 GiB alocados / 530,7 usados; Metadata DUP 7 GiB / 3,99), então
        também não há `balance` pendente — que é o que morde usuário de btrfs a longo prazo.
      • **Swap existe, em duas camadas**: zram 7,7 G em prio 5 (quente, comprimindo 2,7 G
        em 981 MB medidos) e swapfile de 16 G em prio -1 (frio), este com **0 B usados** —
        a camada rápida dá conta sozinha. A prova de que o swapfile está NOCOW correto não
        é o `lsattr`, é o kernel ter aceitado o `swapon`: o btrfs RECUSA ativar swapfile
        que seja CoW ou comprimido, então estar ativo é a validação.
      • **GC já estava certo**: semanal + `--delete-older-than 30d`, mais `nix-optimise`
        diário. Recomendado NÃO apertar — a `/nix/store` inteira são 53 GB de 953 GB, ou
        seja, não é ela que cresce; encurtar a janela custaria cache de rebuild e rollback
        pra recuperar espaço que não falta.
      • ⚠️ ERRO MEU NO CAMINHO, e a mecânica vale mais que o erro: havia `caddy.nix` e
        `services.nix` do dono já no INDEX; eu dei `git add` nos meus dois arquivos e
        commitei — e o `git commit` leva o index INTEIRO, então trabalho alheio entrou no
        meu commit. Desfeito com `reset --soft HEAD~1` + `git commit -- <paths>`, que
        commita só os caminhos dados e deixa o resto do index quieto. REGRA: em árvore com
        trabalho de terceiros staged, commitar SEMPRE por pathspec.
      • O `--dry-run` que eu tinha escrito no comentário do módulo NÃO EXISTE no Docker
        29.6.2 (conferido no `--help` antes de commitar). A prévia real é `docker system
        prune` SEM o `-f`, que lista as categorias e pede y/N.

- [x] `wg-status`: visibilidade do WireGuard sem senha — e um bug de sysupgrade que ela
      revelou (10/08/2026). Não dava pra responder "o celular está conectado?" sem senha de
      root, e ping só prova alcance, não handshake.
      • WRAPPER, NÃO O BINÁRIO: `/usr/bin/wg-status` = `exec /usr/bin/wg show`, subcomando
        fixo e SEM repassar `"$@"`. Pôr `/usr/bin/wg` inteiro no NOPASSWD daria `wg set`, que
        TROCA CHAVE DE PEER — quem tivesse só a chave SSH poderia se inscrever na VPN sem
        senha nenhuma. Sem repasse de argumento não existe `wg-status set`.
      • root:root 0755 e FORA do /home. Se o usuário pudesse escrever no arquivo, reescrevê-lo
        daria root arbitrário sem senha e o wrapper viraria o buraco que existe pra evitar. É
        por isso que ele NÃO foi pra /home/v1cferr/bin/, que seria o lugar cômodo por já estar
        preservado. Forma copiada do /usr/bin/wake-desktop, que já vivia aqui igual.
      • ⚠️ BUG PRÉ-EXISTENTE ACHADO NO CAMINHO: o `/usr/bin/wake-desktop` NUNCA esteve no
        `/etc/sysupgrade.conf`. O sysupgrade preserva `/etc/sudoers.d/` mas NÃO `/usr/bin/`,
        então o próximo upgrade apagaria o binário e DEIXARIA a regra NOPASSWD apontando pro
        vazio — Wake-on-LAN pelo roteador morrendo em silêncio, com a config parecendo certa.
        Regra e alvo têm que ser preservados JUNTOS. Os dois foram listados.
      • O QUE O PRIMEIRO `wg show` MOSTROU, e vale mais que o wrapper:
        1. O celular está conectado (handshake de 1m57s, 3,14 GiB enviados) — mas o endpoint
           é `186.219.82.216`, que é **UFSCar (AS52888)**, bloco `186.219.80.0/20`. Ou seja,
           ele está no WiFi do campus, NÃO em rede móvel. Isso corrige a leitura que eu tinha
           feito do RTT: os 80 ms com jitter de 20 ms não são 4G, são o mesmo caminho do
           notebook (35 ms) mais o salto WiFi.
        2. ⚠️ EXISTE UM TERCEIRO BLOCO DA UFSCAR, e ele NÃO está no `moonlightSources` de
           system/services/sunshine.nix. Consequência prática: Moonlight DIRETO do celular
           seria recusado. Hoje ele funciona só porque a 51820 do WireGuard não tem `src_ip`.
           DECISÃO: não ampliar o allowlist agora — o celular já tem caminho que funciona, e
           abrir mais faixa pra um aparelho que não precisa é troca ruim. Fica registrado pra
           quando alguém perguntar "por que do celular não conecta direto?".
        3. Em 17 DIAS de uptime, só UM peer fez handshake. `notebook` (.2) nunca — coerente,
           é justamente o que o acesso direto de hoje substituiu. Mas `fai-workstation` (.5)
           tem `persistent_keepalive = 25`, ou seja foi configurada pra manter conexão viva, e
           não conectou uma vez. Ou está desligada, ou o peer é legado. Ver pendências.

- [x] Roteador: `/etc/init.d/firewall` entra no NOPASSWD (10/08/2026) — o
      scripts/router-moonlight-forward.sh precisava de senha só pro `reload` do fim, e isso
      o tornava interativo à toa.
      • ⚠️ O RISCO INCREMENTAL É ZERO, e é MEDIDO, não suposto — foi isto que destravou a
        decisão: `/usr/sbin/nft` JÁ era NOPASSWD (confirmado com `sudo -n nft list tables`),
        e `nft flush ruleset` derruba o firewall inteiro. O poder de desligar o firewall sem
        senha já existia, por um caminho PIOR. A mudança só torna utilizável o caminho
        legítimo. Sem essa medição isto teria sido recusado como "escalada de privilégio", e
        a recusa estaria errada.
      • MÉTODO, que vale pra qualquer mexida em sudoers: validar com `visudo -c -f` no
        arquivo CANDIDATO em /tmp, ANTES de encostar no que funciona — sudoers malformado faz
        o sudo recusar tudo, e o conserto exigiria justamente o root que o sudo daria.
        Segunda checagem do conjunto (`visudo -c`) depois de instalar, com rollback.
      • ⚠️ ISTO NÃO É ESPELHADO. O `router-sync` cobre `/etc/config/` e nada mais, então esta
        entrada é o ÚNICO registro da mudança no repo. O `sysupgrade` preserva
        `/etc/sudoers.d/` (está nas 38 entradas do keep.d), então ela sobrevive a upgrade —
        mas não a uma reinstalação limpa.
      • Estado final: `v1cferr ALL=(ALL) NOPASSWD: /sbin/reboot, /usr/sbin/nft, /sbin/uci,
        /etc/init.d/dnsmasq, /etc/init.d/firewall`. Comando arbitrário continua pedindo senha
        (`(ALL) ALL`), que é o certo.

- [x] Moonlight sem VPN: port-forward direto, restrito à UFSCar (10/08/2026) — o pedido era
      "conectar no Sunshine de fora sem entrar na VPN, e direto, sem servidores
      intermediários". A segunda metade do pedido já era verdade e ninguém sabia.
      • ⚠️ A PREMISSA ESTAVA ERRADA, e vale mais que a implementação: **o WireGuard não é um
        servidor intermediário**. O endpoint dele é o PRÓPRIO roteador de casa, então túnel e
        port-forward percorrem exatamente `UFSCar → internet → 177.52.84.188`. Não havia rota
        alternativa a eliminar. Isso ERA risco no Tailscale (podia cair no DERP), e saiu junto
        com ele em 08/08 — o medo sobreviveu à causa. Não reescrever isto como ganho de rota.
      • O QUE SE GANHA DE VERDADE é MTU: 1492 da PPPoE contra ~1420 do túnel. Latência é ruído.
      • O QUE MOTIVA MESMO ASSIM, e é bom motivo: o notebook da FAI já roda nxBender +
        openconnect. Somar um terceiro cliente de VPN ali é conflito de rota esperando
        acontecer — o dono recusou instalar WireGuard por isso, e está certo.
      • PORTAS CONFERIDAS NO BINÁRIO, não em blog: lidos os offsets do web UI do build em uso
        (2026.516.143833, `assets/web/assets/config-*.js`) — tcp `port-5`/`port`/`port+1`/
        `port+21`, udp `port+9`…`port+11`. Quase toda lista na internet inclui uma **UDP 48002
        ("mic") que NÃO EXISTE nesta versão**. São três portas UDP, não quatro.
      • A 47990 (painel admin) ficou DE FORA das duas listas de propósito. O
        `origin_web_ui_allowed = "wan"` só é seguro porque ela não é encaminhada — e o
        comentário que justificava aquele valor ("só a faixa do WireGuard chega nesta porta")
        deixou de ser verdade hoje e foi reescrito.
      • DUAS TRANCAS, e o `-s` do host não é redundante com o `src_ip` do roteador: é a que
        sobrevive a alguém mexer no LuCI sem ler o repo. As listas TÊM que casar — divergir dá
        "roteador encaminha, host derruba", sintoma indistinguível de qualquer outra falha.
      • ⚠️ RESTRIÇÃO NOVA que a mudança criou: `packet_size` é GLOBAL e agora serve dois
        caminhos de MTU diferente. O teto útil vira o do MENOR (o túnel), então 1024 deixou de
        ser conservadorismo e virou trava. Só destrava se o túnel for aposentado.
      • CRIPTOGRAFIA não regride, e isso não era óbvio: o Sunshine classifica cliente por IP.
        Pelo túnel chega 10.10.10.x = LAN → `lan_encryption_mode = 0` (o túnel cifra). Direto
        chega público = WAN → `wan_encryption_mode = 1`, ligado por default.
      • ✅ VALIDADO NO MESMO DIA, com sessão real de 21m58s + 9min. Medições e método completos
        em [testes/moonlight-direto.md](../../testes/moonlight-direto.md); o essencial:
        0% de perda em 100 pacotes de 1 KB, RTT 35,5 ms, jitter 0,54 ms. A prova de que a
        sessão funciona de ponta a ponta foi o próprio Claude passar a rodar SEM `SSH_CLIENT`
        e com `DISPLAY=:0` — dentro da sessão gráfica sendo streamada.
      • O UDP PASSA, e o método de prova vale guardar: o contador de DNAT do roteador marcou
        `Moonlight-Stream-Campus → packets 3`. Esse contador só conta o PRIMEIRO pacote de
        cada fluxo novo (depois o conntrack desvia do dstnat), então 3 = exatamente vídeo
        47998 + áudio 47999 + controle 48000. Depois da reconexão virou 6 — que é como se
        confirmou que houve UMA reconexão, e não várias.
      • `ping_timeout = 20000` absorveu um buraco de 18,9 s às 11:47 sem derrubar a sessão. A
        prova é indireta e vale como método — o guard do hypridle NÃO ciclou (um `Stopped` às
        11:25, nenhum `Started` às 11:47), ou seja o `undo` do prep-cmd nunca rodou, logo o
        Sunshine não desmontou a sessão.
        ⚠️ CORREÇÃO (mesmo dia): a 1ª versão desta linha concluía "o buraco foi do lado da
        UFSCar", porque nada tinha piscado do lado de casa. O dono confirmou depois que foi
        ELE reconectando — nas duas quedas do dia (18,9 s e 104 s). "Não foi aqui" não
        implica "foi a rede": faltava a terceira hipótese, o usuário, e ela era a certa. O
        mecanismo do `ping_timeout` segue medido e verdadeiro; a causa atribuída é que era
        invenção. Não há indício de instabilidade nesta rota — 0% de perda em todos os testes.
      • A ROTA, medida e com os donos por RDAP: roteador → **Alcans (AS52783, o ISP)** →
        Algar (AS16735, TRÂNSITO da Alcans) → IX.br/NIC.br (AS26162) → RNP (AS1916) →
        UFSCar (AS52888). Cinco sistemas autônomos, e NENHUM é servidor intermediário — todos
        encaminham pacote, nenhum termina a conexão. IX.br e RNP não são removíveis: a
        internet da UFSCar vem da RNP. É a resposta empírica ao pedido de "sem servidores
        intermediários", e confirma que o túnel também não tinha.
        ⚠️ CORREÇÃO (mesmo dia): a primeira versão desta linha dizia que a Algar era o ISP,
        porque foi o 1º salto PÚBLICO do traceroute. Errado — o IP de casa (177.52.84.188)
        está em `177.52.80.0/21`, que é **ALCANS TELECOM (AS52783)**. A Algar é o trânsito
        dela. Ler "primeiro salto público" como "meu provedor" é a mesma classe de erro do
        traceroute lido como prova de CGNAT: o salto diz por onde o pacote passou, não de
        quem é a assinatura. Quem responde isso é RDAP no IP de casa, não o traceroute.
      • LATÊNCIA: ruído, como previsto. Os 35 ms são do caminho físico, que o túnel percorria
        igual. Registrado explicitamente para ninguém atribuir ganho a isto depois.

- [x] ~~CGNAT~~ o item morto que sobreviveu à própria correção (10/08/2026) — a entrada de
      07/08 em `docs/pendencias.md` ("NÃO HÁ ENTRADA … NENHUMA regra de port forward pode
      funcionar") continuou lá por três dias DEPOIS de a entrada de 08/08 deste arquivo já a
      ter desmentido inteira. Apagada.
      • O CUSTO NÃO FOI TEÓRICO: ela é a primeira coisa que se lê ao perguntar "dá pra expor
        porta?", e a resposta que ela dá é "não, desista". O trabalho de hoje começou tendo
        que provar que a doc do próprio repo estava errada.
      • REPROVADO HOJE, com método que não mente (ponto externo independente, não a rede da
        FAI): `check-host.net` de Áustria, Canadá e Irã conecta na 2222 de `177.52.84.188`.
        Controle na mesma ferramenta: a 47984 dava `Connection refused` antes das redirects —
        é o que torna o positivo interpretável em vez de só otimista.
      • ⚠️ E O TRACEROUTE CONTINUA PARECENDO CGNAT: saltos 2-4 em `172.31.x` e o 5 em
        `100.127.255.225`, que é faixa `100.64/10` — a faixa DEFINIDA pra CGNAT. Ainda assim
        não é: é transporte interno da operadora. Este é exatamente o instrumento que enganou
        em 07/08, ele não melhorou, e quem repetir a leitura vai errar de novo.
      • A LIÇÃO DE PROCESSO: corrigir no histórico não corrige a pendência. Item revertido tem
        que morrer nos DOIS lugares no mesmo commit, senão o repo passa a ter duas respostas e
        a errada é a que está no arquivo que as pessoas leem primeiro.

- [x] Auth keys do Tailscale revogadas — a exposição de 05/08 fechou (09/08/2026)
      O `.env` órfão na raiz do repo guardava `TAILSCALE=tskey-auth-kLXAR6…` em texto
      claro, modo 644, e a key era **reusable** — o pior caso, porque quem tivesse a
      string entrava na tailnet quantas vezes quisesse. Apagar o arquivo (05/08) reduziu
      a exposição local e NÃO invalidou nada; só a revogação no admin console faz isso.
      Todas as keys foram apagadas pelo dono em 09/08.
      • O Tailscale saiu de uso nesta máquina no caminho: `tailscaled` está `inactive` e
        o binário `tailscale` nem existe no PATH — o que tornou a revogação um ato de
        blast radius zero. Registrado porque é o argumento que destrava esse tipo de
        item: quando nada depende do segredo, revogar deixa de ter contrapartida e a
        única razão pra adiar some.
      • A rota de acesso externo continua sendo a pendência do CGNAT, não esta.

- [x] Auditoria geral do setup, e o que ela achou: a poda do restic estava parada
      há 4 dias (09/08/2026) — varredura completa de hardware e software pedida em aberto
      ("meu sistema está saudável?"). O veredito foi saudável, mas dois achados só
      existiam porque ninguém tinha olhado: os dois se escondiam atrás de ruído que já
      era rotina.
      • 🔴 **restic: `forget --prune` sem rodar desde 05/08 15:46.** `error: lstat
        /home/v1cferr/Drive: permission denied` → restic sai 3 → o `unlock` e o
        `forget --prune`, que são o 2º e o 3º ExecStart, nunca chegam a executar. É a
        MESMA armadilha do `~/FAI-workstation` de 05/08 (FUSE do usuário, backup roda
        como root), com um mountpoint que ninguém lembrou de excluir. Corrigido em
        system/services/restic.nix.
      • O CONSERTO RODOU e o resultado DESMENTIU a estimativa de quem escreveu isto: eu
        avisei que a poda atrasada podia demorar e precisar de mais de uma execução, por
        causa do reempacotamento em repo remoto. Levou **14 s** — removeu 1 snapshot,
        reempacotou 1 pack, liberou 4,9 MiB. Ficaram 6 snapshots / 26,1 GiB.
      • POR QUE FOI TÃO BARATO, que é o que evita superestimar o próximo caso: com
        `--keep-daily 7` e só 5 dias distintos no repo, NADA tinha envelhecido pra fora
        da janela em 4 dias — o único excedente era a duplicata do mesmo dia. O custo de
        retenção morta não cresce linear com os dias parados: ele é ZERO até o repo
        passar de 7 dias distintos, e só então cada dia novo passa a empurrar um pra fora.
      • E ISSO REORDENA QUAL ERA O RISCO DE VERDADE. Não era espaço no Drive: era o
        `unlock`, que é o outro ExecStart que também não rodava. Lock preso de um run
        interrompido bloqueia o backup INTEIRO, não a poda — e esse dano não depende de
        quanto tempo se passou, acontece na primeira vez que um run morre no meio.
      • POR QUE PASSOU DESPERCEBIDO, e esta é a parte que vale guardar: o
        FAI-workstation só monta com a VPN de pé, então falhava de forma INTERMITENTE —
        e foi justamente a intermitência que fez alguém investigar. O `~/Drive` monta em
        TODO boot, então a falha virou constante, diária e silenciosa. Falha que acontece
        SEMPRE é mais fácil de ignorar que falha que acontece às vezes: vira o estado
        normal do serviço. O dado nunca esteve em risco (snapshot salvo todo dia, 41,8
        GiB, 297.740 arquivos) — o que morreu foi a retenção.
      • 🟠 **VS Code: 15 coredumps em 2 dias, e não é o editor.** O que aborta com
        SIGABRT é o language server da extensão `kamikillerto.vscode-colorize` 0.17.1
        (`coredumpctl info` entrega a linha de comando inteira, com o caminho do
        `server/out/server.js`). Preço medido POR aborto: 58 s de CPU, 2,6 GB de pico de
        RAM e 2,7 GB escritos no NVMe só pra gravar o dump — numa máquina de 15 GB e num
        disco cujo desgaste a gente acompanha. Cadência de 09/08: 10:38, 15:01, 15:43,
        15:57, 16:49, 16:55, 17:07.
      • ⚠️ NÃO CONFUNDIR com o "stop job" de 90 s da entrada abaixo, apesar de os dois
        dizerem "VS Code": lá é o `app-code-*.scope` ignorando SIGTERM no DESLIGAMENTO;
        aqui é um processo filho abortando NO MEIO DA SESSÃO. Causas independentes,
        correções independentes — e o risco real era o primeiro achado "explicar" o
        segundo e a investigação parar ali.
      • DESMENTIDOS PELA MEDIÇÃO, que é o que impede trabalho inútil: (a) "15 GB de RAM
        é pouco" — PSI de memória em ~0, swapfile em disco com 0 B usados, zram
        comprimindo 2,7 G em 981 M; o que trava é o colorize, não a RAM. (b) "o NVMe
        está quente" — 52,9 °C de Composite sob carga (jogo + 7 containers + ollama),
        contra os 77-80 °C que geraram a pendência do dissipador; o `Sensor 2` a 79,8 °C
        segue sendo o falso alarme conhecido (sensor não implementado, cravado).
      • Resto verde e conferido: 0 units falhas, `is-system-running: running`, btrfs
        `no errors found`, 58% de disco, fwupd sem update pendente, `nix flake check`
        passando. Secure Boot e VT-x seguem desligados — mesma ida à BIOS, já rastreada.

- [x] Desligamento de 90 s → ~5 s: o "stop job" era UM app, e não o sistema
      (09/08/2026) — a queixa era "demora quase 5 min pra desligar". O journal desmentiu o
      número e entregou o culpado: 90,3 / 90,4 / 90,5 / 90,6 s nos 10 últimos boots. Tempo
      redondo assim não é trabalho, é TIMEOUT — o `DefaultTimeoutStopSec` default do
      systemd, 90 s, batendo inteiro, todo boot.
      • CULPADO ÚNICO e sempre o mesmo: `app-code-*.scope: Stopping timed out. Killing.`.
        O VS Code roda num scope da SESSÃO DO USUÁRIO (o GLib cria `app-<nome>-<pid>.scope`
        ao lançar o `.desktop`) e não responde ao SIGTERM. Buscando o padrão no journal
        inteiro: 8 ocorrências do VS Code e 6 do Chromium antes dele — é comportamento de
        Electron, não desta máquina. Todo o RESTO (docker, jellyfin, rede, unmounts, swap)
        para em menos de 2 s, o que fecha a conta: 90 s de shutdown = 88 s de espera.
      • ONDE ISSO MUDA O DIAGNÓSTICO: o instinto era mexer nos serviços do SISTEMA. Não
        havia nada lá pra ganhar. O ajuste que resolve é do lado do USUÁRIO — 5 s no
        `systemd.user`, onde o inquilino é app de desktop e quem ia salvar no SIGTERM já
        salvou em menos de 1 s.
      • O SISTEMA ficou em 30 s, e não em 5 s junto: `duo` e `grad-radar` têm
        `docker compose down` no ExecStop, e o `down` dá 10 s de carência a CADA container.
        Apertar demais aqui SIGKILLaria o Postgres desses stacks no meio do down — não
        corrompe, mas volta fazendo recovery de WAL, e o preço aparece longe da causa.
      • O QUE A MUDANÇA NÃO FAZ, porque a leitura fácil é "agora mata os apps": o SIGKILL
        já acontecia — 90 s depois. Nada que morria de morte natural passou a ser morto;
        só se deixou de cobrar a espera por quem nunca ia responder.
      • ⚠️ A ARMADILHA QUE A REGRA 8 PEGOU, e ela falha em SILÊNCIO: `systemd.extraConfig`
        FOI REMOVIDA (o 26.05 manda `systemd.settings.Manager`). Escrevendo na opção
        removida, o `nix eval` do `system.conf` gerado PASSA e sai sem a linha — zero erro,
        zero warning, e o desligamento continuaria em 90 s com a config "aplicada". Só
        apareceu porque a validação foi LER o arquivo gerado, não perguntar se buildou.
        E a assimetria é a parte não-óbvia: do lado do usuário `systemd.user.extraConfig`
        continua sendo a ÚNICA forma — `systemd.user.settings` não existe (conferido nas
        `options`, não deduzido do lado do sistema).
      • PRÓXIMA VEZ que o desligamento demorar, o teto global não vai ser a resposta: unit
        com `TimeoutStopSec` próprio ignora o default (hoje qbittorrent tem 30 min, jellyfin
        15 s, caddy 5 s, `user@.service` 2 min do upstream). Procurar primeiro com
        `systemctl show <unit> -p TimeoutStopUSec`.

- [x] Relógio da barra mostra data E hora — e o calendário vira o ano sozinho, medido
      (08/08/2026) — o relógio era um TOGGLE: clique alternava entre `󰥔 HH:mm:ss` e
      `󰃭 dd/MM/yyyy`, nunca os dois. Ver a data custava dois cliques (ida e volta), o que é
      caro para o dado mais consultado da barra. Agora saem juntos na mesma pílula.
      • A FORMA: hora primeiro em mauve, data depois em `Theme.colDim`. Isso é HIERARQUIA,
        não separação — a hora fica na borda esquerda, que é por onde o olho entra na
        pílula, e a data acompanha sem disputar. Nasceu como `sub` novo no `widgets/Pill.qml`
        (texto secundário na mesma pílula), reutilizável para qualquer par que ande junto.
      • DUAS DECISÕES: sem ANO (redundante — o popover de calendário tem, a um hover), e
        dia da semana pelo `dowAbbr` do próprio arquivo em vez do `"ddd"` do Qt. O formato
        do Qt depende do locale do PROCESSO: se a barra subir sem `LC_TIME` — autologin, por
        exemplo — "sáb" vira "Sat" em silêncio. A tabela local não tem esse risco.
      • ⚠️ REGRA 8 NÃO TEM COMO SER CUMPRIDA AQUI, e isso vale saber: a árvore do Quickshell
        é `mkOutOfStoreSymlink`, então NÃO passa pelo `/nix/store` e `nixos-rebuild build`
        não exerce estes arquivos — não existe build para validar. O substituto que usei:
        `qmllint` (sintaxe) + `qml` headless (comportamento) + screenshot do resultado real.
        Erro de QML aqui só aparece com a barra já rodando.
      • A PERGUNTA QUE VALEU A NOITE: "e quando for 2027, o calendário atualiza sozinho?".
        Sim — `SystemClock` bate a cada segundo, `updateClock()` compara `yyyy-MM-dd` com
        `calDayKey` e chama `refreshCalendar()` na primeira batida após a meia-noite. Não
        aceitei de cabeça: simulei a virada 31/12/2026 → 01/01/2027 com as funções REAIS
        extraídas do `Bar.qml` (não uma reescrita) — cabeçalho vira 2027, "hoje" pula para
        01/01, Carnaval pintado em 08-09/02. Páscoa conferida até 2032, inclusive o Carnaval
        de 29/02/2028, bissexto. O algoritmo tem autoteste embutido: se derrapasse num ano, o
        DIA DA SEMANA denunciaria (Páscoa é sempre domingo, Corpus Christi sempre quinta).
      • ⚠️ O ACHADO MAIS VALIOSO, e era o elo que eu só tinha RACIOCINADO: o popover lê
        `calMap` por binding (`Repeater { model: bar.monthCells(...) }`), e binding do QML só
        reavalia quando a PROPRIEDADE é reatribuída. Medido no `qml` headless (6/6):
        reatribuir propaga, MUTAR o objeto por dentro (`calMap[k] = v`) não emite sinal
        nenhum. Ou seja, o calendário só vira o ano porque `refreshCalendar` faz
        `root.calMap = root.buildCalMap(...)`. Quem "otimizar" isso para escrever no objeto
        existente CONGELA o calendário em silêncio: nada quebra, nada loga, só para de virar
        o ano. Anotado no código, junto da função.
      • FERIADOS REVERIFICADOS (nacional + SP + São Carlos) e o resultado foi: NADA MUDOU. A
        lista já estava correta e completa para 2027 — nenhum feriado novo desde a Lei
        14.759/2023 (Consciência Negra, nacional desde 2024, e não mais só estadual).
        Confirmação independente: os não-facultativos da lista somam 14, que é o número que
        a prefeitura e a imprensa local publicam para São Carlos.
      • O QUE MUDOU NOS FERIADOS foi a DOCUMENTAÇÃO, que estava pior do que o código: o
        cabeçalho mandava "ver as notas do workflow" — ponteiro para fora do repo, ou seja,
        para lugar nenhum. As leis entraram no arquivo (662/1949, 6.802/1980, 9.093/1995,
        14.759/2023, estadual 9.497/1997 e a MUNICIPAL 7.502/1974 do Corpus Christi).
      • AS DUAS ARMADILHAS em que os sites de calendário caem e esta lista não — a primeira
        busca que fiz já errou as duas: (1) CARNAVAL e Cinzas não são feriado nacional nem
        municipal em São Carlos, são ponto facultativo; (2) CORPUS CHRISTI é facultativo
        FEDERAL mas feriado MUNICIPAL aqui, pela lei acima — em outra cidade seria `fac`.
      • ⚠️ O QUE NÃO SE ATUALIZA SOZINHO, e é a única parte do calendário assim: a lista
        `holidayDefs`. Os MÓVEIS derivam da Páscoa e escalam para sempre; os FIXOS são LEI
        escrita à mão. Lei nova, ou o município mexendo num feriado, deixa a grade errada em
        silêncio. Revisar quando aparecer notícia de feriado novo — não por virada de ano,
        porque nada ali depende do ano.

- [x] Backlight por DDC/CI REVERTIDO — dimming pior nas duas telas ganha de ótimo em uma
      (08/08/2026) — o `ddcutil` funcionou, a curva funcionou, e mesmo assim saiu. O motivo
      não é técnico, é de ERGONOMIA, e vale mais registrado que o código.
      • O QUE FUNCIONOU: `hardware.i2c.enable` + ddcutil deram controle REAL de backlight no
        DP-2 (LG ULTRAGEAR, MCCS VCP 2.1). A medição que motivou tudo continua válida — o
        monitor estava em **100%** às 20h num quarto escuro, e ISSO era a causa do olho
        ardendo, não o filtro azul. A curva por horário aplicou 40% e o monitor obedeceu.
      • O QUE MATOU: a LG TV do HDMI não tem como acompanhar. Não fala DDC/CI (`x37
        unresponsive`), NÃO ESTÁ NA REDE (conferido no DHCP do roteador: o único dispositivo
        sem nome é Amazon, não LG — então nem webOS), e o HDMI-CEC não cobre brilho, isso é
        de especificação. Três caminhos, três fechados.
      • O RACIOCÍNIO DA REVERSÃO, que é o ponto: uma tela a 32% ao lado de outra a 100%
        obriga a pupila a se readaptar toda vez que o olhar troca, e isso cansa MAIS que o
        ganho na tela boa. Dimming pior nas duas > dimming ótimo em uma, quando as duas
        estão no campo de visão. O gamma do hyprsunset é pior tecnicamente (escurece o
        SINAL, com a luz de fundo no talo) mas alcança AS DUAS — e uniformidade venceu.
      • ⚠️ A ALTERNATIVA que continua valendo, se um dia o incômodo voltar: ajustar o
        backlight da TV UMA VEZ pelo controle remoto dela (é config de aparelho, persiste, e
        cai na mesma categoria do docs/guias/bios-*.md) e retomar o DDC no monitor. Foi
        RECUSADA por não ser automática, não por não funcionar.
      • FICOU do experimento: `wayland-utils` (wayland-info), que entrou junto e é útil por
        si; e a correção do cabeçalho do hyprsunset.nix sobre shader e sobre os 13 perfis.
      • O MONITOR VOLTOU SOZINHO PRA 100%, e eu tinha anotado o contrário: cheguei a
        avisar que "ficou em 40% e persiste no hardware". FALSO — `setvcp` sem `--save`
        não grava na EEPROM, então o valor se perde no primeiro desligamento de tela. A
        reversão ficou completa, sem estado órfão. Vale como armadilha ao contrário: quem
        for automatizar DDC precisa saber que a mudança é VOLÁTIL por padrão, o que aliás
        é bom (um serviço que reaplica no login basta) mas surpreende quem espera que
        `setvcp` grude.

- [x] ~~Gamma sai da curva do hyprsunset~~ REVERTIDO junto com o DDC (08/08/2026) —
      efeito colateral do DDC/CI entrar: o `hyprsunset` NÃO SABE mirar uma saída
      específica. Procurei `output`/`monitor`/`display` no código-fonte: ZERO ocorrências.
      Ele aplica CTM em TODAS as saídas de uma vez.
      • O PROBLEMA QUE ISSO CRIAVA: com o backlight real do DP-2 vindo do DDC/CI, manter o
        auto-dim por gamma daria dimming DUPLO no monitor bom (backlight 32% × gamma 0.9 às
        22h) pra entregar um alívio fraco na TV. Foi regressão que EU introduzi ao adicionar
        o brightness.nix, e só apareceu ao perguntar "e a TV, como funcionaria?".
      • A DIVISÃO QUE FICOU: DP-2 (LG ULTRAGEAR) → backlight de verdade via DDC/CI;
        HDMI-A-3 (LG TV) → ajuste de backlight no controle remoto DELA, que não fala DDC/CI.
        TV é aparelho, não computador: config de imagem persiste lá e não precisa do repo.
      • O `max-gamma = 150` FICOU: os keybinds SHIFT+VolUp/Down seguem ajustando gamma por
        IPC, agora como retoque fino MANUAL em vez de curva automática.
      • HDMI-CEC foi descartado sem teste, e o motivo é de especificação: o protocolo cobre
        ligar/desligar, volume e troca de entrada — brilho não está no padrão. Sobra o
        controle por rede (webOS, TV de 2017), que fica em aberto: não sei o IP dela, e o
        `192.168.1.20` da lease `TV-Samsung-Sala` não responde (nem é certo ser essa TV).

- [x] ~~Brilho REAL do monitor: DDC/CI + curva por horário~~ REVERTIDO (08/08/2026) — o `ddcutil getvcp
      10` devolveu **100** às 20h, num quarto escuro. O monitor passava o dia inteiro no
      talo, e NENHUMA curva de Kelvin resolve isso. Era a causa do olho ardendo.
      • A INVERSÃO QUE MOTIVOU: a literatura de ergonomia põe REDUZIR BRILHO acima de
        temperatura de cor, e "modo noturno não substitui brilho adequado". Eu esperava o
        contrário, e a config esperava também — o `hyprsunset` cobria cor com 13 perfis
        caprichados e luminância com nada.
      • O `gamma` do hyprsunset NÃO ERA BRILHO: ele escurece o SINAL enviado ao painel
        enquanto o backlight segue no talo. A luz que chega no olho não muda. O próprio
        histórico de julho já registrava "sem backlight real" — a lacuna estava anotada e
        ninguém tinha ligado os pontos.
      • `hardware.i2c.enable` (system/hardware/ddc.nix) carrega o `i2c-dev`, que não estava
        carregado porque NADA PEDIA. Sem `/dev/i2c-*` o ddcutil não tem por onde falar.
      • ⚠️ SÓ O DP-2 RESPONDE: o LG ULTRAGEAR fala MCCS (VCP 2.1); a LG TV no HDMI devolve
        "does not support DDC/CI — I2C slave address x37 is unresponsive". E ERREI ao prever
        isso: disse que o HDMI "expunha ZERO barramentos i2c", mas o ddcutil achou o
        `/dev/i2c-7` dele. Meu teste olhava symlinks por conector no sysfs, que é outra
        coisa. A conclusão estava certa pelo motivo errado — a TV TEM barramento, ela é que
        não fala o protocolo.
      • `home/desktop/brightness.nix`: curva por horário espelhando a estrutura do
        hyprsunset (90% de dia → 55% às 18h → 40% às 20h → 28% de madrugada). Timer --user
        de 5 min, e escreve SÓ quando o alvo muda — assim ajuste manual vale até o próximo
        degrau, mesmo contrato do hyprsunset, e não fica escrevendo DDC à toa (é lento e faz
        o monitor piscar). `--model` e não `--display N`: o número muda se outro monitor DDC
        entrar.
      • RECUSADO o `ddcci-driver` (existe no nixpkgs, expõe o monitor como backlight padrão
        e deixaria o `brightnessctl` funcionar): é módulo de kernel out-of-tree, quebra a
        cada bump. Pra infra que precisa durar, chamar o ddcutil de um timer é menos elegante
        e muito menos frágil.
      • Os valores da curva são PONTO DE PARTIDA, não verdade. O critério da literatura é
        comparar com folha de papel branco ao lado da tela.

- [x] LocalSend declarativo, aberto SÓ pra LAN (08/08/2026) — "AirDrop" de código aberto
      (MIT, 1.17.0) pra passar arquivo entre celular e PC sem nuvem e sem conta. Três peças:
      `programs.localsend` em system/net/localsend.nix, a 53317 liberada por ORIGEM e uma
      entrada no painel `my.autostart`.
      • POR QUE NO `system/` e não no `home/`, contra a regra 4: quem une PACOTE + PORTA é o
        módulo do nixpkgs, e firewall é nível-sistema. Mesmo caso do `programs.steam`. O
        pacote NÃO se repete no home/packages.nix — o autostart lê
        `osConfig.programs.localsend.package`, e o store path do `sw/bin/localsend_app` e do
        `ExecStart` da unit CONFEREM (mesmo `5vzlv6k…`), que é a prova de que não duplicou.
        De brinde, isso mata por construção a armadilha do spotify: trocar pro `unstable` no
        system/ leva o autostart junto, em vez de exigir que eu lembre de casar dois arquivos.
      • ⚠️ `openFirewall = false` CONTRA o default do módulo, e a ameaça não é a internet: o
        roteador só encaminha 80/443/2222, então a 53317 nunca esteve exposta ao mundo. Quem
        alcançaria é a VPN — `openFirewall` abre a porta em TODA interface, e com o túnel da
        FAI de pé (`ppp0`) a rede corporativa inteira passaria a enxergar o serviço e a ler o
        `/api/localsend/v2/info` (nome do dispositivo, modelo, fingerprint) sem autenticação
        nenhuma. Vira confiança por ORIGEM, igual à do Sunshine: só `my.net.lanSubnet`.
      • Os peers do WireGuard entram DE GRAÇA, sem regra própria: chegam com origem
        10.10.10.x e a regra de net/network.nix já aceita a faixa antes de qualquer decisão.
        Quinto consumidor da SSOT, validado pelo ritual do sentinela (regra 11): trocar a
        faixa por 172.31.99.0/24 mudou as duas regras novas junto com o `ignoreip` do
        fail2ban, e reverter devolveu o store path IDÊNTICO (`i0kvjns…`).
      • UDP é obrigatório junto com o TCP, e não é detalhe: TCP é a transferência e o `/info`;
        UDP 53317 é o anúncio multicast em 224.0.0.167, que é o que faz os aparelhos se
        DESCOBRIREM. Sem ela o app abre e funciona, mas só por "adicionar por IP" na mão —
        falha que parece "o celular não me acha", não "porta fechada".
      • ⚠️ A porta é REPETIDA no meu módulo porque o do nixpkgs não a expõe como opção (é um
        `firewallPort = 53317` interno ao arquivo dele). Trocar a porta DENTRO do app
        (Configurações → Rede) faz a recepção morrer em SILÊNCIO: sem erro de build, sem log.
      • AUTOSTART com `--hidden` (flag confirmada nas strings do `libapp.so`, não chutada):
        sobe sem janela, só o ícone SNI na tray do quickshell. Sem isso o app não recebe nada
        — o LocalSend só escuta enquanto está aberto, e mandar do celular exigiria ir até o PC
        abrir. Preço explícito: a tray passa a ser o ÚNICO jeito de trazer a janela de volta.
        ⚠️ NÃO ligar o "Autostart after login" DAS CONFIGURAÇÕES DO APP: aquilo escreve um
        `.desktop` em `~/.config/autostart` e viraria um SEGUNDO dono da mesma automação
        (regra 15), com duas instâncias disputando a 53317.
      • ⚠️ CORREÇÃO DE COMENTÁRIO ERRADO que este trabalho destapou, em net/network.nix: eu
        havia escrito que a cadeia `nixos-fw` "termina num refuse, então `-A` nunca é
        alcançada". FALSO pro `extraCommands` — lido no `firewall-start` GERADO, ele é
        injetado ANTES do `-A nixos-fw -j nixos-fw-log-refuse` (nixpkgs 26.05, linha 235 vs
        238), então `-A` funcionaria. A frase só vale pra regra digitada À MÃO num firewall já
        de pé. O `-I 1` continua certo, mas por OUTRO motivo: é ele que reproduz a semântica
        do `trustedInterfaces`. Mesma classe do "`~/.profile` não é lido no OpenWrt" — nota
        antiga que eu ia citar como se fosse fato medido.
      • Apelido, pasta de destino e "salvar sem confirmar" ficam no app (regra 6/14: ele
        reescreve o próprio `shared_preferences` em runtime, o Nix não é dono).

- [x] `my.ingress`: exposição vira TOGGLE (08/08/2026) — o Caddyfile deixou de ser escrito à
      mão. Cada serviço se declara em `my.ingress` (schema em system/net/ingress.nix, painel em
      hosts/nixos-kingston/services.nix) e os vhosts são GERADOS. Alternar alcance = trocar uma
      palavra: `expose = "lan"` ↔ `"public"`.
      • O QUE ISSO CONSERTA: antes o alcance era implícito e assimétrico — `duo`/`ai` tinham
        `respond @externo 403` escrito à mão, `jellyfin`/`torrent` NÃO tinham, e a decisão de
        expor só existia como uma AUSÊNCIA no meio de 60 linhas. Codificar segurança por omissão
        é o pior caso: esquecer de escrever virava "exposto", em silêncio. Agora o default de
        `expose` é `lan` — esquecer FECHA.
      • TAILNET no matcher de casa (100.64.0.0/10): é o que dá acesso remoto DE VERDADE hoje,
        já que o CGNAT impede entrada direta. Um par da tailnet é tão "casa" quanto a LAN. Foi
        junto no `ignoreip` do fail2ban — errar a senha no celular não pode banir a si mesmo.
        ⚠️ Essa faixa é a mesma do CGNAT de carrier; hoje é inofensiva porque nada da internet
        alcança o processo, mas no dia do túnel exige distinguir o caminho, não confiar no IP.
      • `remote_ip` → `client_ip` ANTES de existir túnel: hoje são idênticos (sem proxy
        confiável, cliente = conexão). Custou zero e desarma a armadilha do cloudflared entregar
        pelo loopback e todo o tráfego do túnel virar "casa", furando o basic_auth em silêncio.
        ⚠️ NÃO adicionar `trusted_proxies` enquanto não houver túnel: sem ele o X-Forwarded-For
        é ignorado (que é o certo); com ele, processo local qualquer forja o IP de origem.
      • O failregex do fail2ban passou a ser DERIVADO de quem tem `auth`, em vez do literal
        `pos\.`: serviço novo com basic_auth entra na jail sozinho.
      • ⚠️ PEGADINHA DE NIX que mordeu no primeiro gerado: o alvo é o literal `{$VAR}` (env var
        do Caddy), e `"{$${v}}"` numa string Nix é ERRO DE SINTAXE, não escape — o gerado saiu
        com `{$${v}}` cru, que viraria hash VAZIO em runtime. A forma sem ambiguidade é
        concatenar: `"{$" + v + "}"`. Pegou no olho, no Caddyfile gerado; não haveria erro de
        build.
      • VALIDADO: `caddy validate` com o binário custom e hashes bcrypt reais → `Valid
        configuration`; o gerado é semanticamente idêntico ao que estava à mão; e o ritual do
        sentinela (regra 11) — virar `jellyfin` pra `lan` fez o 403 aparecer, reverter devolveu
        o store path byte-a-byte.

- [x] `router-sync`: a config do roteador sai da cegueira (08/08/2026) — as ~750 linhas de
      UCI do Cudy WR3000 passam a viver em `router/uci/*.conf`, versionadas, com os
      segredos redigidos. NÃO é o roteador declarativo: é ele VISÍVEL e o drift DETECTÁVEL,
      que era a queixa real. `router-sync pull` espelha, `router-sync diff` compara e sai 1
      se divergir (testado nos três estados: sincronia 0, divergência 1, revertido 0).
      • POR QUE NÃO EMPURRA CONFIG, e por que essa metade veio primeiro: escrever UCI por
        SSH exige commit-confirm (aplica → agenda rollback → confirma se ainda houver
        acesso). Sem isso, uma linha errada de rede ou firewall tranca você fora e a saída
        é modo failsafe com acesso FÍSICO. A metade de leitura entrega quase todo o valor
        com nenhum do risco — e o export vira insumo pra QUALQUER ferramenta de push depois.
      • REDAÇÃO FAIL-SAFE, e a direção é o ponto: redige por DEFAULT tudo cujo nome sugira
        credencial, e só libera o que reconhece — `public_key` (público por definição) e
        valor que começa com `/` (é CAMINHO, não segredo). Lista de bloqueio faria o
        contrário e vazaria em silêncio no dia que um pacote novo trouxesse opção nova.
        Validado: os 7 segredos saíram redigidos, e os 2 falsos positivos previstos
        (`luci.flash_keep.passwd='/etc/passwd'`, `uhttpd.main.key='/etc/uhttpd.key'`)
        ficaram intactos pela regra do `/`. Varredura extra por string de alta entropia só
        achou as 3 `public_key` dos peers, um DUID de DHCPv6 e um caminho.
      • `uci show` e não `uci export`: uma linha por opção faz o diff do git apontar a
        LINHA que mudou, em vez do bloco inteiro.
      • ⚠️ `__file__` NÃO acha a raiz do repo: o script é copiado pro /nix/store, então o
        caminho relativo a ele aponta pra dentro da store (read-only). Mordeu na primeira
        execução. O idioma certo é o do `sync-secrets.sh`: `git rev-parse --show-toplevel`.
      • O QUE O `sysupgrade` JÁ PRESERVA — 38 entradas no keep.d, e eu errei DUAS VEZES
        aqui por ler a lista truncada em 12 linhas e concluir do que não vi: `/etc/config/`
        INTEIRO, `/etc/profile.d/`, `/etc/dropbear/`, passwd/shadow/group E TAMBÉM
        `/etc/sudoers.d/`, que eu vinha dizendo que se perdia. A lacuna real é só `/home/`.
      • ⚠️ ARMADILHA que só apareceu ao ler o `/sbin/sysupgrade`: o próprio
        `/etc/sysupgrade.conf` NÃO está no keep.d. O `list_static_conffiles` lê os caminhos
        LISTADOS DENTRO dele, mas não o inclui — então o 1º upgrade preserva o que você
        pediu e o 2º perde tudo, porque o arquivo que pedia sumiu no primeiro. Conserto:
        listar `/etc/sysupgrade.conf` dentro dele mesmo.
      • BOAS PRÁTICAS pesquisadas, pra quando a decisão de push vier: imagem
        (nix-openwrt-imagebuilder + /etc/uci-defaults) e push (nuci/Dewclaw/próprio) são
        COMPLEMENTARES, não alternativas — a imagem é o artefato de desastre, o push é o
        ciclo diário. O `nuci` (github.com/lonerOrz/openwrt-nix) é o mais bem desenhado
        (valida antes, watchdog anti-brick com boot hook, sops, `nuci diff`) e está VIVO
        (push em 30/07/2026), mas tem 1 contribuidor e commits recentes ainda refatorando a
        CLI — churn de API na ferramenta que controla a rede. Dewclaw é mais antigo e o
        autor declarou que não dá suporte.

- [x] `my.net.{lan,vpn}Subnet`: as faixas de casa viram SSOT (08/08/2026) — última ponta
      solta da saída do Tailscale. "De casa" é decisão de SEGURANÇA (separa quem entra
      direto de quem precisa de senha) e estava escrita por extenso em QUATRO lugares:
      matcher `@externo` do Caddy, `ignoreip` da jail caddy-pos, `ignoreIP` do sshd e a
      regra de firewall que substituiu o `trustedInterfaces`. Divergir ali não dá erro de
      build — só passa a tratar como estranho quem devia entrar, ou o contrário.
      • DUAS opções e não uma lista só: o firewall que mantém o Sunshine alcançável confia
        SÓ na do WireGuard. O Sunshine é fechado na LAN por decisão, e mesclar as faixas o
        abriria pra rede de casa inteira sem ninguém perceber.
      • Validado pelo ritual do sentinela: trocar `vpnSubnet` por 172.31.99.0/24 mudou os
        QUATRO consumidores juntos; reverter devolveu o store path.
      • ACHADO DE BRINDE, duas configs mortas que o sentinela expôs: o `[DEFAULT]` do
        fail2ban saía com `127.0.0.1/8 ::1` DUPLICADO (o módulo do nixpkgs já prepende os
        dois — declarar de novo repetia), e o `ignoreip` da jail caddy-pos virou idêntico
        ao DEFAULT depois que ambos passaram a ler a SSOT. Jail sem `ignoreip` herda o
        default: uma cópia a menos pra divergir.
      • ⚠️ Estes valores ESPELHAM o roteador, que é quem realmente os define (ele serve o
        DHCP da LAN e é o servidor WireGuard). O Nix não alcança lá — mudar a faixa no
        OpenWrt e esquecer daqui deixa o repo mentindo em silêncio.

- [x] Tailscale REMOVIDO — só WireGuard (08/08/2026) — o acesso remoto passa a ser o
      WireGuard que o ROTEADOR já servia, e a malha de terceiro sai inteira do repo.
      • POR QUE, e a premissa que eu tinha errado: o cliente do Tailscale JÁ é FOSS
        (BSD-3); o proprietário é o plano de CONTROLE. Então a troca não tira software
        fechado da máquina — tira a dependência de um coordenador de terceiro que sabe
        quais dispositivos existem e pode desligar a rede. O Headscale resolveria isso
        também, mas custa um serviço crítico a manter; WireGuard puro custa zero, porque
        o servidor já estava no roteador (`wg0`, 10.10.10.0/24) e o Caddy já confiava
        nessa faixa.
      • O QUE DERRUBOU O ÚNICO ARGUMENTO CONTRA: o medo era rede corporativa bloquear UDP
        e obrigar o relay DERP — exatamente o caso de uso (Moonlight do trabalho). MEDIDO:
        3 pacotes UDP 51820 disparados da FAI, contador `Allow-WireGuard` do nftables no
        roteador foi de 0 → 3. Passa. E sem relay o vídeo vai sempre direto, o que pra
        streaming é ganho puro — o caminho é mais curto ainda, já que a FAI e a casa estão
        as duas em São Carlos.
      • ⚠️ A PEGADINHA QUE QUASE PASSOU: o `tailscale.nix` carregava
        `trustedInterfaces = [ "tailscale0" ]`, e o Sunshine roda com `openFirewall =
        false`. Apagar o módulo sem substituir isso deixaria o Sunshine INALCANÇÁVEL de
        todo lugar, em silêncio. O substituto está em net/network.nix e é por ORIGEM, não
        por interface: o servidor WireGuard é o ROTEADOR, então não existe `wg0` local pra
        confiar — o peer chega pela LAN com origem 10.10.10.x. Regra inserida com
        `-I nixos-fw 1`: a cadeia termina num refuse, então `-A` nunca seria alcançada.
      • MORREU JUNTO, e é o ponto do "zero legado": o subsistema `sunshine-path-probe`
        (~82 linhas + 2 units systemd) e as seções do `moonlight-stats` que cruzavam o
        journal do tailscaled. Tudo aquilo existia pra responder "esta sessão foi direta
        ou caiu no DERP?" — com WireGuard não há relay, então a pergunta PERDEU O OBJETO.
        Não foi código que quebrou; foi código que deixou de ter sentido. O relatório
        manteve o que continua verdadeiro: duração das sessões e a divisão curtas/longas.
      • Sumiu também o `after = tailscaled.service` do cloudflare-dyndns: aquela corrida
        de DNS existia porque o resolv.conf apontava pro 100.100.100.100 servido pelo
        próprio tailscaled. O RETRY ficou — a outra causa (DHCP demorando ~6,5s depois do
        network-online) é independente e continua valendo.
      • AJUSTES FUNCIONAIS no sunshine.nix: `csrf_allowed_origins` apontava pro IP da
        tailnet e pro nome MagicDNS, ambos mortos → virou `https://192.168.1.10:47990`,
        que é por onde o peer chega. Continua SNAPSHOT (não dá pra derivar IP em build) —
        vale garantir lease fixa no roteador. O `packet_size = 1024` FICOU: foi calibrado
        pra MTU 1280 da tailscale0 e sobra espaço na MTU ~1420 do WireGuard, mas é valor
        provado e subir seria otimização sem medição, arriscando reintroduzir o descarte
        SILENCIOSO que custou o debug de 29/07.
      • ⚠️ O QUE SE PERDE, e é real: o Tailscale re-resolvia o endpoint sozinho quando o
        IP de casa mudava. O WireGuard guarda o endpoint resolvido e NÃO re-resolve — se
        o IP mudar enquanto você está fora, a sessão morre e o cliente não volta só. Tem
        conserto (timer que re-resolve e reaplica), mas é trabalho, não mágica de terceiro.
      • `tailscale_authkey` saiu do índice do Bitwarden. O valor CIFRADO continua no
        secrets.yaml até alguém removê-lo à mão — inofensivo, mas é resíduo.

- [x] Roteador OpenWrt: acesso, limpeza e `owfetch` (08/08/2026) — o Cudy WR3000 virou
      administrável por SSH sem senha, e ganhou um resumo de sistema. NADA disso é
      declarativo, e o registro existe por isso: o OpenWrt não é NixOS, então tudo abaixo
      é passo MANUAL que some num reflash limpo (sobrevive a `sysupgrade` com keep settings).
      • CLIENTE declarativo, resto não: `home/shell/ssh.nix` ganhou o host `router`. Sem o
        `faiResilience` — aquilo dimensiona keepalive e multiplexação pro túnel SonicWall;
        num salto de LAN de <1ms seria carga cultuada.
      • OS CINCO PASSOS MANUAIS, na ordem: (1) `ssh-copy-id` da chave; (2) `@includedir
        /etc/sudoers.d` no `/etc/sudoers` — ele NÃO vinha, então drop-in ali era ignorado em
        SILÊNCIO; (3) a regra NOPASSWD restrita; (4) o script em `~/bin/owfetch`; (5) a
        chamada em `/etc/profile.d/99-owfetch.sh`. Somar `/etc/sudoers.d/` ao
        `/etc/sysupgrade.conf` faz o passo 3 persistir.
      • ⚠️ NÃO existe `su` no BusyBox e `sudo cmd > arquivo` NÃO funciona (o `>` é do shell
        sem privilégio, antes do sudo). O padrão é `| sudo tee`. E editar sudoers é
        copiar → editar a CÓPIA → `visudo -c -f` → só então instalar: com `sudo` quebrado e
        sem `su`, a saída seria failsafe com acesso físico.
      • ESCOPO DO SUDO: começou `ALL` e foi ESTREITADO pra `/sbin/reboot, /usr/sbin/nft,
        /sbin/uci, /etc/init.d/dnsmasq`. O motivo é que `NOPASSWD: ALL` + chave SSH torna a
        CHAVE equivalente a root — e o login de root por SSH já estava desativado no
        dropbear (flags `-w -g`), então o amplo desfazia a proteção que já existia.
      • DNS LOCAL: 13 entradas → 1. Só `/v1cferr.dev/192.168.1.10` fazia trabalho — no
        dnsmasq isso cobre o domínio E todos os subdomínios. As 12 específicas eram
        redundantes, várias apontando pra serviços mortos no Arch (bazarr/prowlarr/radarr/
        sonarr/jellyseerr/spendflow/chat/dash/files), e nenhuma cobria `pos` nem `duo`.
        Backup em `/etc/config/dhcp.bak-limpeza`. Efeito aceito: a curinga pega o APEX, então
        `https://v1cferr.dev` de dentro de casa dá erro de TLS (o cert curinga não cobre o
        domínio nu). De fora vai pra Vercel normalmente.
      • `scripts/owfetch.sh`: fetch em ash puro, ~4 KB, ZERO dependência. Não é fastfetch
        porque o /overlay tem 1.4 MB livres de 6.1 MB — fastfetch pesa 1-2 MB e o neofetch
        arrastaria o bash; qualquer um enche a flash, e roteador com flash cheia não grava
        nem config. A ordem dos campos espelha `home/shell/fastfetch.nix` de propósito.
      • AUTOSTART em `/etc/profile.d/99-owfetch.sh` (o `/etc/profile` varre esse diretório).
        Guardas obrigatórias: `[ -t 1 ]` (senão suja `scp` e comandos por SSH) e `-x` (senão
        erra se o script sumir num reflash). `$HOME` e não caminho fixo: o diretório é lido
        por CADA usuário que loga, então quem não tiver o script simplesmente não vê nada.
      • ⚠️ MÉTODO, e a lição vale mais que o resultado: eu cheguei a ANOTAR AQUI que
        "`~/.profile` não é lido no OpenWrt". FALSO — ele é lido, e o login real mostrou o
        fetch rodando DUAS vezes só com ele. O que enganou foi o teste: `echo exit | ssh -tt`
        NÃO é uma sessão interativa (o ash olha `isatty(0)`, e stdin veio de um pipe), então
        ele devolve zero tanto para "não configurado" quanto para "configurado e funcionando".
        Um método que não distingue as duas hipóteses não é teste — e foi a MESMA classe de
        erro do CGNAT: instrumento cego lido como evidência.
      • ⚠️ printf pad por BYTE: o rótulo "Memória" desalinhava porque `ó` são 2 bytes em
        UTF-8. Virou "RAM". E o ARM não expõe `model name` em /proc/cpuinfo — o nome da CPU
        sai do `DISTRIB_ARCH`.
      • O hook `shellcheck` entrou no `flake.nix` por causa deste script: o
        `scripts/sync-secrets.sh` já ganhava verificação de graça pelo `writeShellApplication`,
        mas o `owfetch.sh` roda em ash NO ROTEADOR e nenhuma derivação o embrulha — seria o
        único `.sh` do repo a executar em máquina alheia SEM verificação. Ligar o hook exigiu
        `# shellcheck shell=bash` no `.envrc`, que não tem shebang (SC2148).

- [x] ~~CGNAT~~ FALSO ALARME: o acesso externo SEMPRE funcionou (08/08/2026) — esta entrada
      nasceu ERRADA em 07/08 e fica reescrita, não apagada, porque o valor está no método que
      falhou. A conclusão de ontem ("não há rota de entrada, é CGNAT") era falsa nas TRÊS pernas:
      • NÃO há CGNAT. O roteador tem o IP público direto na `pppoe-wan`. O `172.31.43.240` que
        eu li como "NAT da operadora" no traceroute é o PEER do enlace PPPoE. Saltos em RFC 1918
        num traceroute não provam CGNAT — operadora usa espaço privado em transporte, e isso
        aparece igual nos dois casos. Foi inferência, vendida como prova.
      • A operadora NÃO bloqueia. Provado pelo contador do nftables (`nft list chain inet fw4
        dstnat_wan`): 3 disparos de fora = contador +3. Os pacotes sempre chegaram.
      • O acesso externo FUNCIONA. Provado pela borda da Cloudflare: registro `proxied` temporário
        → a CF conectou no Caddy e recebeu o `404 Subdomínio não configurado` em 0,39s, com o
        contador do roteador subindo junto. Encerrou a questão.
      • QUEM BLOQUEIA É A REDE DA FAI. Era o meu único ponto externo, e não é neutra: o SYN sai
        de lá e chega aqui, o conntrack do roteador mostra `SYN_RECV` (ou seja, o Caddy RESPONDE
        o SYN-ACK), e o ACK final nunca volta. O firewall da FAI descarta o SYN-ACK.
      • ⚠️ MÉTODO — três formas de o teste MENTIR, todas cometidas aqui:
        1. DE DENTRO DA LAN: o roteador faz hairpin e a porta "abre". Falso positivo.
        2. PELA VPN DA FAI com o túnel ATIVO no alvo: `ip route get 200.136.209.229` sai por
           `ppp0` com origem `192.168.50.1` — a resposta volta por outro caminho e o cliente
           descarta. Falso NEGATIVO, e o mais traiçoeiro, porque parece um teste externo legítimo.
        3. PONTO EXTERNO ÚNICO: se ele mesmo bloqueia, tudo parece quebrado. Uma rede corporativa
           não pode ser juiz do próprio caso — exige um SEGUNDO ponto independente.
      • A FERRAMENTA QUE RESOLVEU, guardar pra próxima: criar um registro `proxied` na Cloudflare
        e bater nele. A CF vira um ponto externo NEUTRO que já é seu, sem terceiros e sem VPN. O
        `404` do catch-all é o sinal perfeito — não precisa nem de serviço no ar. Apagar depois.
      • CONSEQUÊNCIAS: `expose = "public"` FUNCIONA hoje. Não precisa de cloudflared, não precisa
        ligar pra operadora, e a armadilha do `trusted_proxies` vira teórica de novo (mas o
        `client_ip` fica, porque continua certo).
      • ⚠️ E O RISCO REAL INVERTE: `jellyfin` e `torrent` estão expostos à internet AGORA, com o
        login do próprio app como única barreira. Ontem isso era teórico ("nada alcança"); hoje é
        fato. O wildcard resolve pra cá, a 443 está encaminhada e o Caddy serve os dois sem gate.
        Decidir conscientemente: manter, ou virar `expose = "lan"` no painel.

- [x] `my.ingress`: exposição vira TOGGLE (08/08/2026) — o Caddyfile deixou de ser escrito à
      mão. Cada serviço se declara em `my.ingress` (schema em system/net/ingress.nix, painel em
      hosts/nixos-kingston/services.nix) e os vhosts são GERADOS. Alternar alcance = trocar uma
      palavra: `expose = "lan"` ↔ `"public"`.
      • O QUE ISSO CONSERTA: antes o alcance era implícito e assimétrico — `duo`/`ai` tinham
        `respond @externo 403` escrito à mão, `jellyfin`/`torrent` NÃO tinham, e a decisão de
        expor só existia como uma AUSÊNCIA no meio de 60 linhas. Codificar segurança por omissão
        é o pior caso: esquecer de escrever virava "exposto", em silêncio. Agora o default de
        `expose` é `lan` — esquecer FECHA.
      • TAILNET no matcher de casa (100.64.0.0/10): é o que dá acesso remoto DE VERDADE hoje,
        já que o CGNAT impede entrada direta. Um par da tailnet é tão "casa" quanto a LAN. Foi
        junto no `ignoreip` do fail2ban — errar a senha no celular não pode banir a si mesmo.
        ⚠️ Essa faixa é a mesma do CGNAT de carrier; hoje é inofensiva porque nada da internet
        alcança o processo, mas no dia do túnel exige distinguir o caminho, não confiar no IP.
      • `remote_ip` → `client_ip` ANTES de existir túnel: hoje são idênticos (sem proxy
        confiável, cliente = conexão). Custou zero e desarma a armadilha do cloudflared entregar
        pelo loopback e todo o tráfego do túnel virar "casa", furando o basic_auth em silêncio.
        ⚠️ NÃO adicionar `trusted_proxies` enquanto não houver túnel: sem ele o X-Forwarded-For
        é ignorado (que é o certo); com ele, processo local qualquer forja o IP de origem.
      • O failregex do fail2ban passou a ser DERIVADO de quem tem `auth`, em vez do literal
        `pos\.`: serviço novo com basic_auth entra na jail sozinho.
      • ⚠️ PEGADINHA DE NIX que mordeu no primeiro gerado: o alvo é o literal `{$VAR}` (env var
        do Caddy), e `"{$${v}}"` numa string Nix é ERRO DE SINTAXE, não escape — o gerado saiu
        com `{$${v}}` cru, que viraria hash VAZIO em runtime. A forma sem ambiguidade é
        concatenar: `"{$" + v + "}"`. Pegou no olho, no Caddyfile gerado; não haveria erro de
        build.
      • VALIDADO: `caddy validate` com o binário custom e hashes bcrypt reais → `Valid
        configuration`; o gerado é semanticamente idêntico ao que estava à mão; e o ritual do
        sentinela (regra 11) — virar `jellyfin` pra `lan` fez o 403 aparecer, reverter devolveu
        o store path byte-a-byte.

- [x] Cloudflare no Claude Code: CLI + MCP (07/08/2026) — pra fechar a "descoberta pendente" do
      Caddy (o wildcard respondendo IP privado) sem eu ler zona no painel na mão. Duas peças:
      `.mcp.json` na raiz e `.claude/settings.json`.
      • O `wrangler` ENTROU E SAIU no mesmo dia, e o motivo vale registrar porque eu ia repetir:
        assumi que o "CLI oficial da Cloudflare" serviria pra DNS. NÃO SERVE — o help inteiro é
        Workers/Pages/KV/R2/AI/Queues, e não existe `wrangler dns` nem nada de zona. E o preço
        era 2.2 GiB de closure, QUATRO cópias de nodejs-24 (slim, -npm, -corepack e o cheio):
        sozinho, +1.91 GiB dos +2.10 GiB daquele switch. Contradizia o próprio critério que
        usei duas linhas abaixo pra recusar as skills de Workers. Quem faz DNS é o MCP.
      • ESCOPO É PROJETO, e NÃO global, contra o que eu tinha pedido — porque global e
        declarativo são MUTUAMENTE EXCLUSIVOS aqui, e vale registrar o porquê. Os três escopos
        de MCP do Claude Code: `local` e `user` (=global) moram em `~/.claude.json`; só
        `project` mora em `.mcp.json`, versionado. E o `~/.claude.json` é o arquivo que guarda
        `numStartups`, `tipsHistory`, `projects`, cache de features — o app REESCREVE em
        runtime, então pela regra 14 o Nix não pode ser dono dele. Global = imperativo. Fim.
      • A ROTA DE FUGA EXISTE E FOI RECUSADA: `/etc/claude-code/managed-mcp.json` seria
        declarativo (`environment.etc`) E global, o único jeito de ter os dois. Mas ele tem
        controle EXCLUSIVO: "Claude Code loads only the servers that file defines. Users cannot
        add, modify, or use any other MCP servers, including plugin-provided servers." Isso
        MATARIA o github, o atlassian e os connectors do claude.ai. Trocar 4 servidores que
        funcionam por 1 é péssimo negócio — e project scope resolve 100% do caso de uso, já que
        o trabalho de DNS/Caddy é NESTE repo.
      • O plugin oficial (`cloudflare/skills`, que a doc manda instalar) foi ABERTO e RECUSADO:
        traz 5 servidores MCP e 13 skills, e 11 delas são Workers/Durable Objects/Pages/
        Turnstile — plataforma de dev que eu não uso. Sobrou o que serve: `cloudflare-api`
        (DNS, zonas, tokens) e `cloudflare-docs`. Os 3 descartados eram `bindings`, `builds` e
        `observability`. Marketplace foi removido depois de inspecionado, não ficou órfão.
      • `enabledMcpjsonServers` no `.claude/settings.json` PRÉ-APROVA os dois: sem ele o Claude
        pergunta a cada sessão. Só vale em workspace confiável — repo clonado não se auto-aprova.
      • Auth é OAuth no browser, na PRIMEIRA chamada de tool — não tem token no repo (regra 12).
        Credencial SEPARADA do token sops do `cloudflare-dyndns`; não confundir os dois.
      • ⚠️ `.mcp.json` é JSON estrito, sem comentário — por isso o "porquê" está aqui e não lá.

- [x] Caddy de volta, declarativo (07/08/2026) — a "Fase 4 — Homelab" começou. O ingress do Arch
      (`caddy/etc/caddy/Caddyfile` na branch `main`/`arch`) tinha ficado para trás na migração:
      `services.caddy` agora serve `*.v1cferr.dev` com cert CURINGA da LE via DNS-01 da
      Cloudflare, e `my.net.domain` (system/net/domain.nix) virou o SSOT do domínio — antes o
      literal existia num lugar só (o DDNS), o que não justificava opção; com o proxy o
      consumidor virou quatro e disparou a regra 11.
      • O motivo da maior gambiarra do setup antigo MORREU: buildar com xcaddy e esconder o
        binário em `/usr/local/bin` existia porque "um `pacman -Syu` já sobrescreveu o binário
        custom uma vez e derrubou o proxy inteiro". No Nix é `caddy.withPlugins` com o vendor
        fixado por hash — o pacote É a declaração.
      • ⚠️ `propagation_timeout -1` foi PRESERVADO literal. Não é preferência: a checagem local
        de propagação do certmagic falha neste host, e sem desligá-la a emissão trava.
      • PRIMEIRO `networking.firewall.allowedTCPPorts` do repo (80/443). Todo o resto usa o
        `openFirewall` do módulo upstream, mas `services.caddy` não tem um. O roteador já
        encaminhava 80/443/2222 desde o Arch — quem bloqueava era o firewall do NixOS.
      • AUTO-GATE nos 4 segredos (padrão do duo.nix), porque `{$VAR}` vazio vira hash de
        basic_auth vazio e o Caddy recusaria a config INTEIRA — inerte é melhor que derrubar o
        proxy no switch.
      • Validado SEM switch: ritual do sentinela da regra 11 (DDNS + vhost + 5 matchers +
        failregex trocaram juntos) e `caddy validate` no Caddyfile gerado, com o binário custom,
        dando `Valid configuration`.
      • ~~Descoberta pendente: o wildcard responde IP privado~~ — RESOLVIDA em 07/08/2026, e o
        diagnóstico estava ERRADO. Não havia wildcard nenhum na Cloudflare: a zona tinha 10
        registros e nenhum `*`. Quem respondia `192.168.1.10` era o ROTEADOR (192.168.1.1), que
        tem um wildcard local `*.v1cferr.dev` → 192.168.1.10 configurado nele, fora do Nix —
        split-horizon pra LAN não fazer hairpin pelo WAN. O erro foi MEDIR DE DENTRO DA REDE:
        `dig @1.1.1.1` também dava privado porque o roteador sequestra a porta 53. Quem
        desempatou foi DNS-over-HTTPS (porta 443, insequestrável): de fora, `ssh` sempre
        resolveu certo pro IP público, e nome aleatório dava NXDOMAIN. O `cloudflare-dyndns`
        nunca esteve quebrado. LIÇÃO: pra validar DNS público de dentro da própria LAN, DoH —
        `dig` mente quando há interceptação.
      • WILDCARD ADICIONADO (07/08/2026): `*` CNAME → `ssh.v1cferr.dev`, DNS-only. CNAME e não
        A de propósito: o `cloudflare-dyndns` só gerencia `ssh.${domain}` (network.nix:67), então
        o wildcard HERDA o IP dinâmico de graça — um A ficaria congelado no primeiro IP. Isso
        casa com o desenho que o Caddyfile já tinha: cert curinga + catch-all `respond
        "Subdomínio não configurado" 404`. Antes disso, NENHUM dos cinco vhosts (pos/duo/ai/
        jellyfin/torrent) tinha registro — de fora, o proxy inteiro era inalcançável.
      • ⚠️ O risco de wildcard + DNS-01 foi TESTADO, não assumido: se o wildcard atropelasse o
        `_acme-challenge.*`, a renovação do cert quebraria em ~60 dias, em silêncio. Consultado
        via DoH, um TXT explícito sob o wildcard continua sendo devolvido como TXT (RFC 4592:
        registro explícito tem precedência). Renovação segura.
      • ZONA LIMPA no mesmo dia: 10 registros → 3. Saíram os dois TXT `_acme-challenge` órfãos
        (`prowlarr`/`torrent`, sobra do Arch — o certmagic não limpou), o `tv` A → 179.135.127.74
        (IP MORTO: o DDNS só gerencia `ssh`, e por ser explícito o `tv` ganhava do wildcard e
        seguia quebrado — removido, agora herda o IP vivo) e `ap`/`dash`/`files` CNAME → `ssh`,
        que o wildcard tornou redundantes. Ficaram só `A ssh` (alvo do DDNS e do wildcard),
        `A v1cferr.dev` proxied (o site no Vercel) e o `CNAME *`.
      • Os NS `ns1/ns2.dns-parking.com` também saíram. Eram sobra da importação da HOSTINGER, e
        a checagem que autorizou remover: a delegação REAL vive no REGISTRADOR, não na zona — e
        `dig NS` já devolvia só `bruce/zoe.ns.cloudflare.com`, provando que a Cloudflare nunca
        serviu aqueles dois. Nada da Hostinger precisa existir na zona; o vínculo é o painel
        deles apontando pra Cloudflare. (Se um dia entrar e-mail no domínio, aí sim: MX + SPF.)
      • ⚠️ PEGADINHA do split-horizon: o wildcard do ROTEADOR cobre também o APEX, então de
        dentro da LAN `https://v1cferr.dev` bate no Caddy e dá ERRO DE TLS — o cert `*.v1cferr.dev`
        NÃO cobre `v1cferr.dev` nu (wildcard não casa o próprio domínio). Não está quebrado: pela
        borda da Cloudflare o apex responde 307 normal. Só não dá pra testar o apex de casa.

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
      • `[KDE] SingleClick=false` (duplo clique) entrou e SAIU no mesmo dia. O pedido é
        semelhança de INTERFACE, e clique é COMPORTAMENTO — não muda um pixel. Pior: mora no
        kdeglobals, então mudaria TODO app KDE por causa do file manager. Serve de régua pro
        resto: mexer no que se VÊ, não no que se USA.
      • O guia "pixel-perfect" que circula (vrunox-9714/dolphin-win11-theme) foi RECUSADO, e
        não por preguiça: depende de regra do **KWin** pra sumir com a barra de título (aqui é
        Hyprland, não há KWin) e de um QSS via `--stylesheet`, que brigaria com o Kvantum que
        já desenha todo o Qt. Antes de copiar receita de tema, checar se ela pressupõe Plasma.
      • TOOLBAR estilo Explorer: TENTADA E RECUSADA no mesmo dia (07/08/2026). Não commitada,
        e o `~/.local/share/kxmlgui5/dolphin/dolphinui.rc` foi apagado. Motivo primário: NÃO
        GOSTOU do resultado — o Explorer tem DUAS faixas (endereço em cima, comandos embaixo)
        e o Dolphin só tem UMA toolbar, então tudo se amontoa numa linha e fica pior que o
        default limpo. Não é limitação de config, é do Dolphin.
        Havia também um custo que sozinho já pedia cautela: o `.rc` carrega `version="48"` e
        quando o Dolphin subir pra 49 o KXMLGUI DESCARTA o arquivo em silêncio — a toolbar
        voltaria ao padrão sem erro nenhum. Mesma classe de drift do ViewMode.
        Se alguém insistir: é activation idempotente e nunca `home.file` (regra 14, o Dolphin
        reescreve o arquivo no "Configurar barras de ferramentas"). Mas o veredito é NÃO.
      • Onde o visual PAROU: ícones + as 5 chaves acima. O que sobraria exige brigar com o
        Kvantum (QSS) ou com um KWin que não existe aqui — ou seja, não sobra nada barato.

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

- [x] Remover todos os outros hosts e manter apenas o atual — hoje só hosts/nixos-kingston/.
      O nixos-sandisk saiu em 02/08/2026: o disco dele virou o Windows 11, então o host não
      era mais nem rollback nem alvo. Molde pra host novo se pega no histórico do git.

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
