# ═══════════════════════════════════════════════════════════════════════════
# Ollama — runtime de modelos de IA LOCAIS (systemd, sobe no boot). Roda em CPU
# (i5-11400): a Arc B580 não tem aceleração Ollama simples no nixpkgs ainda
# (dependeria de SYCL/oneAPI ou ipex-llm) — explorar depois. O qwen3:4b (~2.6 GB)
# roda tranquilo em CPU, só mais devagar.
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
{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    # CPU-only: `pkgs.ollama` puro (sem CUDA/ROCm). Aceleração na Arc B580 fica
    # pra depois (ver cabeçalho) — hoje o solver roda na CPU.
    package = pkgs.ollama;
    # Escuta só em 127.0.0.1:11434 (padrão) — os containers do duo (network_mode:
    # host) alcançam localhost sem expor o Ollama na LAN.
    # qwen3:4b = solver texto-primeiro (não precisa de visão); bge-m3 = embeddings
    # p/ a memória few-shot do duo-streak-daemon. Pull na ativação (idempotente).
    loadModels = [ "qwen3:4b" "bge-m3" ];
  };
}
