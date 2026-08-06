# ═══════════════════════════════════════════════════════════════════════════
# Ollama — runtime de modelos de IA LOCAIS (systemd, sobe no boot). Roda na GPU
# (Arc B580) por VULKAN, via `pkgs.ollama-vulkan`.
#
# `services.ollama.acceleration` NÃO existe mais (mkRemovedOptionModule): hoje
# aceleração é escolha de PACOTE — ollama / -cpu / -rocm / -cuda / -vulkan. E
# `pkgs.ollama` puro NÃO é a GPU: sem rocmSupport/cudaSupport ele é igual ao
# -cpu, que era exatamente o que rodava aqui antes.
#
# POR QUE Vulkan e não SYCL/oneAPI/ipex-llm: Vulkan fala com o Mesa ANV, que já
# está no sistema (hardware/gpu.nix) e é o MESMO driver do resto do desktop —
# zero dependência nova, zero empacotamento à mão. O caminho SYCL exigiria
# empacotar o fork da Intel (ipex-llm), que não está no nixpkgs.
# Medido em 06/08/2026, no startup: `library=Vulkan description="Intel(R)
# Arc(tm) B580 Graphics (BMG G21)" type=discrete total=11.9 GiB`. O llvmpipe
# (Vulkan em CPU) é descartado sozinho — não precisa de GGML_VK_VISIBLE_DEVICES.
# O hardening do módulo já libera a placa: `DeviceAllow` tem `char-drm` (major
# 226 = /dev/dri/*) e `SupplementaryGroups = [ "render" ]`.
#
# ⚠️ Pegadinha: o backend Vulkan do ollama tem relato de crash em Arc sob decode
# de alta frequência (ollama#14207). Se aparecer, o fallback é trocar por
# `pkgs.ollama-cpu` — UMA linha, e sem tocar no driver de vídeo.
#
# É o "cérebro" (solver) do duo-streak-daemon: o daemon extrai o exercício do DOM
# e o Ollama decide a resposta — 100% local, sem cota, sem enviar dados a terceiros.
# O stack do duo (docker-compose) foi desenhado pra falar com o Ollama do HOST
# (network_mode: host → OLLAMA_HOST=http://localhost:11434), então ele mora aqui,
# nativo, e não em container.
#
# O modelo (qwen3:4b, ~2.6 GB) é baixado declarativamente via loadModels — o
# ollama-model-loader (systemd) faz o pull na ativação e é idempotente (pula se
# já existe). Teste: `ollama run qwen3:4b`.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, config, ... }:

{
  services.ollama = {
    enable = config.my.services.ollama;
    package = pkgs.ollama-vulkan; # GPU (Arc B580) via Mesa ANV — ver cabeçalho
    # Escuta só em 127.0.0.1:11434 (padrão) — os containers do duo (network_mode:
    # host) alcançam localhost sem expor o Ollama na LAN.
    # qwen3:4b = solver texto-primeiro (não precisa de visão); bge-m3 = embeddings
    # p/ a memória few-shot do duo-streak-daemon. Pull na ativação (idempotente).
    loadModels = [
      "qwen3:4b"
      "bge-m3"
    ];
  };
}
