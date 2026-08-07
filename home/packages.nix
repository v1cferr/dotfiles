# ═══════════════════════════════════════════════════════════════════════════
# PACOTES DO USUÁRIO (home-manager) — a lista CENTRAL. É AQUI que você adiciona
# um app/CLI novo SEM config própria (espelha o system/packages.nix). Apps COM
# config declarativa vivem no seu módulo (programs.* ou apps/desktop/shell):
# kitty, git, dolphin, flameshot, media, vscode, quickshell, tema, helpers do Hyprland.
# unfree ok (allowUnfree herdado do system).
#
# `pkgs.foo` = base estável (26.05); `pkgs.unstable.foo` = canal bleeding-edge.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    # ── Navegadores ──
    librewolf # Firefox hardened (privacidade)
    # Chrome canal DEV (unstable/latest), NÃO o stable — via flake browser-previews
    # (o nixpkgs só tem stable). Binário/launcher = "Google Chrome Dev"; bump com
    # `nix flake update browser-previews`. unfree; compatibilidade/DevTools bleeding-edge.
    inputs.browser-previews.packages.${stdenv.hostPlatform.system}.google-chrome-dev
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default # Zen (flake; ver flake.nix)

    # ── Comunicação ──
    discord # voz/chat (unfree; expõe o socket IPC pro Rich Presence do Claude Code)

    # ── IA ──
    # Claude Desktop (GUI: Chat/Cowork/Code) — .deb OFICIAL reempacotado, ver flake.nix.
    # Variante FHS e não a pura: os servidores MCP precisam achar node/uv, e o Cowork
    # sobe uma VM QEMU procurando /usr/share/OVMF/*.fd e /usr/bin/virtiofsd em caminhos
    # FHS HARDCODED — fora do FHS ele responde "virtualization_tools_missing" e pronto.
    # Closure MEDIDO: 2.9 GiB (o qemu_kvm é a maior fatia) — a medição de 30/07 diz que
    # não é onde o disco enche: o /nix/store INTEIRO é 9% dele, os Bottles são 319 GiB.
    # ⚠️ Cowork exige VT-x LIGADO NA BIOS (aqui está desligado: "VMX disabled by BIOS")
    # + o usuário no grupo kvm. Sem isso, só Chat/Code funcionam. A sessão e o claude_desktop_config.json são
    # ESTADO (regra 6 → restic) e o app REESCREVE esse JSON em runtime (regra 14: o
    # Nix não é dono dele). unfree.
    claude-desktop-fhs

    # ── Notas / mídia ──
    obsidian # notas em Markdown (cofre local; unfree)
    # Música (unfree). UNSTABLE e não a base: a 1.2.90.451 da 26.05 NÃO ABRE mais aqui
    # (MEDIDO 07/08/2026) — o zygote do CEF morre antes do primeiro ping, o browser
    # aborta com "GPU process isn't usable. Goodbye." e o processo cai de SIGTRAP em
    # ~250ms, sem janela e sem erro visível. Não é a Arc B580 nem o perfil: `--disable-gpu`
    # e `--no-sandbox` não mudam nada, e `--no-zygote` contorna. A 1.2.92.147 do unstable
    # abre limpa, SEM flag — por isso a correção é a versão, não um workaround no launcher.
    # Voltar pra `spotify` puro quando a base alcançar ≥1.2.92.
    unstable.spotify

    # ── Editor / dev ──
    # O VS Code (pacote + settings.json/keybindings.json versionados) mora em
    # home/apps/vscode.nix — app COM config própria é dono do seu pacote.
    #
    # Toolchain Nix que a extensão nix-ide DIRIGE — o pacote é declarativo aqui, a
    # config da extensão não (home/apps/vscode/settings.json + .vscode/settings.json
    # do repo). Os dois são resolvidos por NOME no $PATH: caminho do
    # /nix/store dentro de settings.json quebraria no primeiro nix-collect-garbage.
    #
    # nixd e NÃO nil: os dois são LSP de Nix vivos, mas só o nixd completa OPÇÕES de
    # NixOS/home-manager, porque compila contra o próprio interpretador e AVALIA a
    # config em vez de analisar texto. Num repo que é 95% `services.*`/`programs.*`,
    # isso é a função inteira. O nil é melhor no resto (mais leve, diagnóstico bom) —
    # se um dia o nixd pesar, ele é o plano B, trocando 1 linha aqui e o serverPath.
    nixd
    # nixfmt e NÃO nixpkgs-fmt/alejandra: é o formatter OFICIAL desde a RFC 166, que
    # criou o Nix formatting team e moveu o repo pra org NixOS. O nixpkgs-fmt está
    # DEPRECIADO pelo próprio autor; o alejandra é bom mas não-oficial, e divergir do
    # nixpkgs em estilo é dívida gratuita. Atenção ao nome: `nixfmt` JÁ É o RFC-style
    # (1.4.0, mesmo derivation que nixfmt-rfc-style); `nixfmt-classic` (0.6.0) é o
    # antigo — pedir o clássico por engano reformataria o repo inteiro no estilo velho.
    nixfmt
    # LINT, o que o nixd NÃO faz: ele entende a linguagem, não julga o estilo nem acha
    # código morto. Os dois entram junto porque respondem perguntas diferentes e o gate
    # do flake (`checks` em flake.nix) roda ambos:
    #   statix  → anti-padrão idiomático (ex.: `a = x.a;` que devia ser `inherit (x) a;`)
    #   deadnix → declaração MORTA (arg de lambda, let-binding e pattern não usados)
    # Aqui é só disponibilidade pra rodar na mão; quem GARANTE é o `nix flake check`.
    # Config do statix em ./statix.toml — dois lints desligados com justificativa lá,
    # porque 63 dos 77 achados iniciais eram um único lint que contraria a idioma do
    # nixpkgs (caminho pontilhado).
    statix
    deadnix

    # ── Torrent / senhas ──
    qbittorrent # torrent GUI (uso manual) — separado do serviço headless (system/services/qbittorrent.nix)
    bitwarden-desktop # GUI Electron (Electron 39 EOL liberado em system/core/core.nix)
    bitwarden-cli # `bw` — consultar/scriptar o cofre no terminal

    # ── Jogos / emuladores (bottles/ROMs/instâncias são ESTADO → backup, regra 6) ──
    (bottles.override { removeWarningPopup = true; }) # Wine/Proton FHS-wrapped; popup "Unsupported" silenciado
    rpcs3 # emulador PS3 (Uncharted 1/2/3); firmware + jogos = estado, você provê
    prismlauncher # Minecraft nativo p/ modpacks (vem wrapped com os JDKs 8/17/21)

    # ── Disco / limpeza ──
    # Complementa o filelight (que mostra PASTAS): o czkawka acha o que é
    # DESCARTÁVEL — duplicatas, arquivos grandes, pastas vazias, temporários,
    # imagens/vídeos semelhantes. É a peça que faltava p/ decidir o que remover
    # em vez de só ver o que é grande. GUI = `czkawka_gui` (ou `krokiet`, a nova);
    # `czkawka_cli` p/ script. NÃO apaga nada sozinho — sempre lista primeiro.
    czkawka

    # ── CLIs ──
    gh # GitHub CLI (auth/push via HTTPS + token)
    # NÃO adicionar `wrangler` aqui: TESTADO E REMOVIDO em 07/08/2026, no mesmo dia em que
    # entrou. Custa 2.2 GiB de closure (QUATRO cópias de nodejs-24: slim, -npm, -corepack e
    # o cheio) e NÃO tem comando de DNS/zona — o help inteiro é Workers/Pages/KV/R2/AI.
    # O trabalho de DNS aqui é feito pelo MCP `cloudflare-api` (.mcp.json na raiz).
    unstable.claude-code # este assistente de código (bleeding-edge — evolui rápido)
    unstable.yt-dlp # baixa vídeo/áudio (unstable pq quebra quando os sites mudam)
    unstable.speedtest-cli # teste de velocidade (unstable: acompanha mudanças do speedtest.net)
  ];
}
