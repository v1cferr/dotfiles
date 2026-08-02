# ═══════════════════════════════════════════════════════════════════════════
# PACOTES DO USUÁRIO (home-manager) — a lista CENTRAL. É AQUI que você adiciona
# um app/CLI novo SEM config própria (espelha o system/packages.nix). Apps COM
# config declarativa vivem no seu módulo (programs.* ou apps/desktop/shell):
# kitty, git, dolphin, flameshot, media, waybar, tema, helpers do Hyprland. unfree
# ok (allowUnfree herdado do system).
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
    spotify # música (unfree)

    # ── Editor / dev ──
    # VS Code: override --password-store=gnome-libsecret — no Hyprland o Electron não
    # autodetecta o backend de secret e mostra "couldn't identify OS keyring"; a flag
    # força o gnome-keyring. Extensões/settings = Settings Sync (conta), NÃO nix.
    (vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })

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
    unstable.fastfetch # resumo do sistema (bleeding-edge: hardware/versões novas)
    unstable.claude-code # este assistente de código (bleeding-edge — evolui rápido)
    unstable.yt-dlp # baixa vídeo/áudio (unstable pq quebra quando os sites mudam)
    unstable.speedtest-cli # teste de velocidade (unstable: acompanha mudanças do speedtest.net)
  ];
}
