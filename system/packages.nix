# ═══════════════════════════════════════════════════════════════════════════
# PACOTES DE SISTEMA (nível-root) ─────────────────────────────────────────────
# Só ferramentas de NÍVEL-SISTEMA: resgate/base, diagnóstico e o que root/serviços
# precisam. Apps e CLIs de USUÁRIO vivem no home/ (regra 4): programs.* quando há
# módulo, senão home.packages agrupado por categoria (ver home/apps, home/shell).
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
    gdu # analisador de uso de disco TUI (Go), ~5× mais rápido que ncdu em disco grande (`sudo gdu -x /`)
    kdePackages.filelight # analisador de uso de disco GUI (KDE, gráfico sunburst); integra c/ Dolphin/Kvantum
    jq # processa/consulta JSON no terminal (usado no fluxo de segredos c/ bw)
    openssl # gerar senhas/chaves (rand), TLS, etc.
    python3 # interpretador Python (rodar scripts; libs por projeto ficam no uv/venv)
    uv # gerenciador Python rápido (venv/deps/pythons); os pythons dele rodam via nix-ld
    unzip # descompacta .zip (utilitário base)
    bitwarden-cli # `bw` — consultar/scriptar o cofre no terminal (fluxo de segredos)

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
    # Launcher de Minecraft (open-source) p/ modpacks. Roda NATIVO — não precisa de
    # Bottles/Wine (bem mais rápido/estável que o app do CurseForge no Wine). O pacote
    # do nixpkgs vem wrapped com os JDKs (Java 8/17/21), então o Prism autodetecta o
    # Java 21 que o Minecraft 1.21.1 + NeoForge exige — sem config extra. As instâncias
    # e mods são ESTADO (~/.local/share/PrismLauncher) — não se declaram (regra nº 1).
    prismlauncher

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
