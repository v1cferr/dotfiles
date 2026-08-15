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
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # ── base estável ──
    git
    vim
    htop
    dmidecode
    btop # monitor de recursos (CPU/mem/disco/rede) com TUI rica; htop turbinado
    tree # lista a árvore de diretórios no terminal
    gdu # analisador de uso de disco TUI (Go), ~5× mais rápido que ncdu em disco grande (`sudo gdu -x /`)
    kdePackages.filelight # analisador de uso de disco GUI (KDE, gráfico sunburst); integra c/ Dolphin/Kvantum
    # O gdu/filelight respondem "qual PASTA pesa"; este responde "qual PACOTE pesa", que é
    # outra pergunta: mostra o closure ordenado por tamanho e o que cada dep arrasta.
    # Foi como se mediu que o xembedsniproxy custava 429 MiB de qtwebengine (30/07).
    nix-tree # navega o closure de uma derivação por TAMANHO (`nix-tree /run/current-system`)
    jq # processa/consulta JSON no terminal (usado no fluxo de segredos c/ bw)
    openssl # gerar senhas/chaves (rand), TLS, etc.
    python3 # interpretador Python (rodar scripts; libs por projeto ficam no uv/venv)
    uv # gerenciador Python rápido (venv/deps/pythons); os pythons dele rodam via nix-ld
    unzip # descompacta .zip (utilitário base)
    # RESGATE (critério 3 do README): o módulo services.restic gera só wrappers POR REPO
    # (`restic-home-gdrive`), então repo sem serviço — como o arquivo do Arch — ficava
    # inalcançável sem `nix shell`. Backup que exige ginástica pra ler é meio backup.
    restic # cliente do restic p/ inspecionar/restaurar QUALQUER repo (ver docs/history/)

    # ── GPU: monitoramento (Arc B580) ──
    # Os benches (vulkan-tools/mesa-demos/glmark2/vkmark/unigine/clpeak) foram
    # removidos após validar a Arc — eram one-off. Ficam só os monitores do dia-a-dia.
    nvtopPackages.intel # monitor de GPU ao vivo (util/clock/VRAM/temp) — Intel
    intel-gpu-tools # intel_gpu_top — engines/freq do driver Intel
    # Lista os protocolos Wayland que o compositor expõe e o que cada saída suporta.
    # Entrou em 08/08/2026 porque a pergunta "o Hyprland ainda serve wlr-gamma-control?"
    # não tinha como ser respondida sem chutar — e chute vira comentário errado no repo.
    wayland-utils # wayland-info
  ];
}
