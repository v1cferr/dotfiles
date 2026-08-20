# OLLAMA: a runtime for LOCAL models, on the Arc B580 through Vulkan.
# Why the -vulkan package and not `acceleration`, and the Arc crash: docs/notes/services/ollama.md
{ pkgs, config, ... }:

{
  services.ollama = {
    enable = config.my.services.ollama;
    package = pkgs.ollama-vulkan; # the GPU (Arc B580) through Mesa ANV; see the header
    # The VRAM-tiered default lands on 4k HERE, which truncates any agent prompt; see the note.
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "32768"; # ~1 GB of KV cache, still 100% GPU
    # It listens only on 127.0.0.1:11434; duo's containers (network_mode: host) reach it there.
    # qwen3:4b = the solver, bge-m3 = embeddings, qwen3.5 = tool calling. Pulled at activation.
    loadModels = [
      "qwen3:4b"
      "bge-m3"
      "qwen3.5"
    ];
  };
}
