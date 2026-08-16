# Ollama on the Arc B580

`system/services/ollama.nix`. A runtime for local models, on the GPU through Vulkan
(`pkgs.ollama-vulkan`).

## Acceleration is a package choice now

`services.ollama.acceleration` does NOT exist anymore (`mkRemovedOptionModule`). Acceleration is
picked by PACKAGE: `ollama` / `-cpu` / `-rocm` / `-cuda` / `-vulkan`. And plain `pkgs.ollama` is
NOT the GPU: with no `rocmSupport`/`cudaSupport` it is the same as `-cpu`, which is exactly what
used to run here without anyone noticing.

## Why Vulkan and not SYCL/oneAPI/ipex-llm

Vulkan talks to Mesa ANV, which is already on the system (`system/hardware/gpu.nix`) and is the
SAME driver as the rest of the desktop: zero new dependencies, zero hand packaging. The SYCL path
would mean packaging Intel's fork (ipex-llm), which is not in nixpkgs.

Measured on 06/08/2026 at startup:

```text
library=Vulkan description="Intel(R) Arc(tm) B580 Graphics (BMG G21)" type=discrete total=11.9 GiB
```

llvmpipe (Vulkan on the CPU) is discarded on its own, so `GGML_VK_VISIBLE_DEVICES` is not needed.
The module's hardening already lets the card through: `DeviceAllow` has `char-drm`
(major 226 = `/dev/dri/*`) and `SupplementaryGroups = [ "render" ]`.

## The trap

Ollama's Vulkan backend has reports of crashing on Arc under high-frequency decode
(ollama#14207). If that shows up, the fallback is `pkgs.ollama-cpu`, ONE line, without touching
the video driver.

## Why it is native and not a container

It is duo-streak-daemon's solver: the daemon extracts the exercise from the DOM and Ollama decides
the answer, 100% locally, with no quota and without sending data to third parties. duo's compose
was designed to talk to the HOST's Ollama (`network_mode: host`, so
`OLLAMA_HOST=http://localhost:11434`).

## The models

`loadModels` downloads them declaratively: `ollama-model-loader` (systemd) pulls at activation and
is idempotent. `qwen3:4b` (~2.6 GB) is a text-first solver, it does not need vision; `bge-m3` is
the embeddings model for duo-streak-daemon's few-shot memory. To test: `ollama run qwen3:4b`.
