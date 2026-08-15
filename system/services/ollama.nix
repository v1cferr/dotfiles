# ═══════════════════════════════════════════════════════════════════════════
# Ollama: a runtime for LOCAL AI models (systemd, it comes up at boot). It runs on the GPU (the
# Arc B580) through VULKAN, using `pkgs.ollama-vulkan`.
#
# `services.ollama.acceleration` does NOT exist anymore (mkRemovedOptionModule): today acceleration
# is a PACKAGE choice, ollama / -cpu / -rocm / -cuda / -vulkan. And plain `pkgs.ollama` is NOT the
# GPU: with no rocmSupport/cudaSupport it is the same as -cpu, which is exactly what used to run
# here.
#
# WHY Vulkan and not SYCL/oneAPI/ipex-llm: Vulkan talks to Mesa ANV, which is already on the
# system (hardware/gpu.nix) and is the SAME driver as the rest of the desktop, so zero new
# dependencies and zero hand packaging. The SYCL path would require packaging Intel's fork
# (ipex-llm), which is not in nixpkgs.
# Measured on 06/08/2026, at startup: `library=Vulkan description="Intel(R) Arc(tm) B580 Graphics
# (BMG G21)" type=discrete total=11.9 GiB`. llvmpipe (Vulkan on the CPU) is discarded on its own,
# so GGML_VK_VISIBLE_DEVICES is not needed.
# The module's hardening already lets the card through: `DeviceAllow` has `char-drm` (major
# 226 = /dev/dri/*) and `SupplementaryGroups = [ "render" ]`.
#
# A trap: ollama's Vulkan backend has reports of crashing on Arc under high-frequency decode
# (ollama#14207). If that shows up, the fallback is switching to `pkgs.ollama-cpu`, ONE line, and
# without touching the video driver.
#
# It is duo-streak-daemon's "brain" (the solver): the daemon extracts the exercise from the DOM and
# Ollama decides the answer, 100% locally, with no quota and without sending data to third
# parties. duo's stack (docker-compose) was designed to talk to the HOST's Ollama
# (network_mode: host, so OLLAMA_HOST=http://localhost:11434), which is why it lives here, native,
# and not in a container.
#
# The model (qwen3:4b, ~2.6 GB) is downloaded declaratively through loadModels: the
# ollama-model-loader (systemd) does the pull at activation and is idempotent (it skips if it
# already exists). To test: `ollama run qwen3:4b`.
# ═══════════════════════════════════════════════════════════════════════════
{ pkgs, config, ... }:

{
  services.ollama = {
    enable = config.my.services.ollama;
    package = pkgs.ollama-vulkan; # the GPU (Arc B580) through Mesa ANV; see the header
    # It listens only on 127.0.0.1:11434 (the default), and duo's containers (network_mode: host)
    # reach localhost without exposing Ollama on the LAN.
    # qwen3:4b = a text-first solver (it does not need vision); bge-m3 = embeddings for
    # duo-streak-daemon's few-shot memory. The pull happens at activation (idempotently).
    loadModels = [
      "qwen3:4b"
      "bge-m3"
    ];
  };
}
