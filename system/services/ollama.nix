# OLLAMA: a runtime for LOCAL models, on the Arc B580 through Vulkan.
# Why the -vulkan package and not `acceleration`, and the Arc crash: docs/notes/services/ollama.md
{ pkgs, config, ... }:

{
  services.ollama = {
    enable = config.my.services.ollama;
    package = pkgs.ollama-vulkan; # the GPU (Arc B580) through Mesa ANV; see the header
    # It listens only on 127.0.0.1:11434; duo's containers (network_mode: host) reach it there.
    # qwen3:4b = the solver, bge-m3 = embeddings. Pulled at activation, idempotently.
    loadModels = [
      "qwen3:4b"
      "bge-m3"
    ];
  };
}
