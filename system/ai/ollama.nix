# ═══════════════════════════════════════════════════════════════════════════
# Ollama — runtime de modelos de IA LOCAIS (systemd, sobe no boot), acelerado
# por GPU (CUDA, RTX 3050 Ampere).
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
{ config, pkgs, ... }:

{
  services.ollama = {
    enable = true;
    # Segue a GPU (system/gpu.nix): CUDA na NVIDIA (RTX 3050); CPU no perfil Intel
    # Arc (Ollama ainda não tem GPU Intel simples no nixpkgs). B580 → explorar depois.
    package = if config.my.gpu == "nvidia" then pkgs.ollama-cuda else pkgs.ollama;
    # Escuta só em 127.0.0.1:11434 (padrão) — os containers do duo (network_mode:
    # host) alcançam localhost sem expor o Ollama na LAN.
    # qwen3:4b = solver texto-primeiro (não precisa de visão); bge-m3 = embeddings
    # p/ a memória few-shot do duo-streak-daemon. Pull na ativação (idempotente).
    loadModels = [ "qwen3:4b" "bge-m3" ];
  };
}
