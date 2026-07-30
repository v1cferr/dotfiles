# ═══════════════════════════════════════════════════════════════════════════
# NÚCLEO — Nix/flakes, nixpkgs (unfree/inseguros), nix-ld, locale/idioma e os TETOS
# de crescimento em disco (GC da store + journald).
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  # ── Nix / flakes ─────────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true; # dedup por hardlink na /nix/store
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d"; # a /nix/store não cresce pra sempre
  };
  # GC reativo por espaço (complementa o timer acima): se durante um build o
  # espaço livre cair abaixo de min-free, coleta lixo até liberar max-free e
  # segue o build. Evita "no space left" no meio de um rebuild grande.
  #
  # SUBIDO de 1 GiB/5 GiB (30/07): 1 GiB é TARDE DEMAIS p/ ser rede de segurança —
  # começar a coletar só quando sobra 1 GiB é chegar depois do acidente, e o build que
  # disparou a coleta provavelmente já falhou. Aqui a partição é COMPARTILHADA com jogos
  # e mídia (medido: 506 GiB entre Bottles/Jellyfin/Steam contra 58 GiB de store), então
  # o espaço pode sumir por fora do Nix e o Nix precisa de folga real. 15 GiB de piso dá
  # margem p/ um rebuild grande; 50 GiB de alvo evita coletar de novo no build seguinte.
  # NOMES: neste Nix (2.34.8) são min-free/max-free — o rename p/ gc-threshold/gc-limit +
  # auto-gc é de versão mais nova e NÃO existe aqui (conferido com `nix config show`).
  nix.settings.min-free = 15 * 1024 * 1024 * 1024; # 15 GiB — piso p/ disparar o GC
  nix.settings.max-free = 50 * 1024 * 1024 * 1024; # 50 GiB — alvo a liberar quando dispara

  # ── Teto do journal ──────────────────────────────────────────────────────
  # SEM isto o journald usa o default: 10% do filesystem. Nesta máquina (915 G) são
  # ~92 GiB que ele pode ocupar LEGITIMAMENTE, sem nada denunciar — o tipo de
  # crescimento que só se descobre com o disco cheio. Hoje são 530 MiB, então 2 GiB é
  # teto folgado e ainda guarda semanas de histórico. Lição concreta de 30/07: dois
  # timers meus escreviam 2148 linhas/DIA aqui antes de ganharem LogLevelMax.
  # SystemMaxFileSize limita cada arquivo → a rotação é gradual, não em degraus de 1/8.
  services.journald.extraConfig = ''
    SystemMaxUse=2G
    SystemMaxFileSize=128M
  '';
  # Prioridade OCIOSA do nix-daemon: os builds (que maxam os cores compilando) CEDEM
  # CPU/disco à sessão interativa → rebuild/upgrade não trava o desktop nem o stream do
  # Moonlight. Máquina parada = build usa tudo normal (idle só cede quando algo mais quer).
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nixpkgs.config.allowUnfree = true; # google-chrome, vscode, etc.
  # bitwarden-desktop (Electron) trava no Electron 39 (EOL). Nenhum canal migrou
  # ainda; liberamos SÓ esta versão. Ao bumpar o Bitwarden, revisar/remover isto.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  # ── Compat com binários FHS (nix-ld) ──────────────────────────────────────
  # NixOS não roda binários dinâmicos "genéricos" (que buscam /lib64/ld-linux…).
  # O nix-ld provê esse loader → faz funcionar VS Code Remote-SSH (vscode-server),
  # wheels Python/CUDA (uv pip install torch), etc. (item "dia 1" do README).
  programs.nix-ld.enable = true;

  # ── Local / idioma ─────────────────────────────────────────────────────────
  # Sistema em en-US (por preferência: output/erros em inglês facilitam o debug).
  # EXCEÇÃO: a LOCKSCREEN é full pt-BR (por gosto) → por isso geramos pt_BR também,
  # que o relógio do lockscreen usa via LC_TIME pra data por extenso (home/desktop/
  # lockscreen.nix). Timezone/teclado seguem BR (fuso local + teclado físico ABNT2).
  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "pt_BR.UTF-8/UTF-8" ];
  console.keyMap = "br-abnt2"; # teclado no TTY (a GUI é no desktop.nix)
}
