# ═══════════════════════════════════════════════════════════════════════════
# PACOTES DE SISTEMA (nível-root) ─────────────────────────────────────────────
# Apps e ferramentas system-wide. Pacotes de USUÁRIO com integração de shell
# (eza, fzf, zoxide…) ficam no home/ (programs.*). Ver home/default.nix.
#
# `pkgs.foo`          → versão da BASE estável (26.05). Use por padrão.
# `pkgs.unstable.foo` → versão BLEEDING-EDGE (canal unstable). Só o que você
#                       quiser sempre na última. Overlay definido no flake.nix.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, inputs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── base estável ──
    git
    gh # GitHub CLI (auth/push via HTTPS + token)
    vim
    htop
    dmidecode
    btop # monitor de recursos (CPU/mem/disco/rede) com TUI rica; htop turbinado
    tree # lista a árvore de diretórios no terminal
    jq # processa/consulta JSON no terminal (usado no fluxo de segredos c/ bw)
    openssl # gerar senhas/chaves (rand), TLS, etc.
    python3 # interpretador Python (rodar scripts; libs por projeto ficam no uv/venv)
    uv # gerenciador Python rápido (venv/deps/pythons); os pythons dele rodam via nix-ld
    kitty # terminal do Hyprland default (SUPER+Q)
    wofi # launcher do Hyprland default (SUPER+R)
    waybar # barra de status (workspaces + relógio); config em home/waybar.nix
    pavucontrol # GUI de mixer/dispositivos (PipeWire via compat PulseAudio)
    # Screenshot: flameshot v13 ESTÁVEL + enableWlrSupport (grim). Por que NÃO o
    # v14 (unstable): o v14 removeu o adapter de grim e captura só via
    # xdg-desktop-portal — que NÃO entrega neste Hyprland ("Unable to capture
    # screen"). O v13 tem o `useGrimAdapter` (ligado no .ini, home/), que usa o grim
    # direto e funciona (testado). enableWlrSupport = põe o grim no PATH do wrapper.
    (flameshot.override { enableWlrSupport = true; })
    pamixer # controle de volume via CLI (pros keybinds de mídia do Hyprland)
    playerctl # play/pause/next via CLI (teclas de mídia)
    cliphist # histórico de clipboard no Wayland (guarda texto/imagem; picker via wofi)
    wl-clipboard # wl-copy/wl-paste — base do clipboard Wayland (o cliphist depende dele)
    wl-clip-persist # mantém o clipboard vivo após o app de origem fechar (ex.: imagem do Flameshot)
    gnome-themes-extra # tema GTK Adwaita-dark (usado pelo home/theme.nix)
    fluent-icon-theme # ícones estilo Windows 11 (Fluent-dark; config no home/theme.nix)
    bibata-cursors # tema de cursor Bibata-Modern-Ice (config no home/)
    librewolf
    google-chrome
    inputs.zen-browser.packages.${pkgs.system}.default # Zen (flake; ver flake.nix)
    # override: --password-store=gnome-libsecret — no Hyprland o Electron não
    # autodetecta o backend de secret (XDG_CURRENT_DESKTOP não é GNOME/KDE) e mostra
    # "couldn't identify OS keyring"; a flag força o uso do gnome-keyring (libsecret).
    (vscode.override { commandLineArgs = "--password-store=gnome-libsecret"; })
    spotify # unfree (ok: allowUnfree acima)
    # whatsapp  # (estava comentado na config original)
    unzip
    qbittorrent # app GUI de torrent (janela, uso manual) — separado do serviço headless (media/qbittorrent.nix)
    obsidian # notas em Markdown (cofre local; unfree — ok pelo allowUnfree acima)

    # ── Gerenciador de senhas: Bitwarden ──
    # desktop trava no Electron 39 EOL (liberado em permittedInsecurePackages
    # no core.nix — os dois canais fixam o mesmo Electron, então fica no estável).
    bitwarden-desktop # app desktop (GUI Electron)
    bitwarden-cli # `bw` — consultar/scriptar o cofre no terminal

    # ── Jogos: Wine/WoW via Bottles ──
    # `bottles` do nixpkgs vem FHS-wrapped → os runners (GE-Proton/wine-staging)
    # rodam no NixOS. A(s) bottle(s) em si são ESTADO (~/.local/share/bottles),
    # copiadas do Kingston — não se declaram (regra nº 1).
    # removeWarningPopup: silencia o aviso "Unsupported Environment" (o Bottles upstream
    # só suporta Flatpak/sandbox; no NixOS é FHS-wrapped e funciona — o popup é ruído).
    (bottles.override { removeWarningPopup = true; })
    # Emulador de PS3 (roda a trilogia Uncharted 1/2/3, que é PS3). Usa Vulkan (Arc
    # ok). Firmware (PS3UPDAT.PUP da Sony) e jogos são ESTADO — você provê, não declara.
    rpcs3

    # ── Gerenciador de arquivos: Dolphin (KDE) ──
    # GUI mais completo: split view, abas, terminal embutido, previews. Os pacotes
    # extras é que ligam os recursos: kio-extras = SFTP/SMB/MTP (celular via USB);
    # thumbnailers = miniaturas de imagem/pdf/vídeo. Lixeira (trash:/) é nativa.
    kdePackages.dolphin
    kdePackages.kio-extras
    kdePackages.kdegraphics-thumbnailers
    kdePackages.ffmpegthumbs

    # ── GPU: monitoramento (Arc B580) ──
    # Os benches (vulkan-tools/mesa-demos/glmark2/vkmark/unigine/clpeak) foram
    # removidos após validar a Arc — eram one-off. Ficam só os monitores do dia-a-dia.
    nvtopPackages.intel # monitor de GPU ao vivo (util/clock/VRAM/temp) — Intel
    intel-gpu-tools # intel_gpu_top — engines/freq do driver Intel

    # ── bleeding-edge (escolhidos a dedo) ──
    unstable.fastfetch
    unstable.claude-code
    unstable.yt-dlp # baixa vídeo/áudio; unstable pq quebra quando os sites mudam (precisa da última)
  ];
}
