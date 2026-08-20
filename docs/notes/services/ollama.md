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

`qwen3.5` (9B q4_K_M, 6.6 GB) is the one that calls tools, and the only one here that
sustains an agent loop. Measured on the B580 on 20/08/2026: 681 tok/s of prefill on an
8.3k-token prompt, 44 to 54 tok/s of decode, 100% GPU. The 27B of the same family does NOT
fit: 18 GB against 11.9 GiB of VRAM, and the 15 GiB of system RAM leave no room to offload
the rest either.

## The context default is 4k here, whatever the VRAM suggests

`ollama serve --help` describes the default as "4k/32k/256k based on VRAM", and this machine
lands on the FLOOR. Measured on 20/08/2026, with 11.9 GiB free: `qwen3:4b` AND the 9B
`qwen3.5` both load showing `CONTEXT 4096` in `ollama ps`. The tier is not decided per model,
so pulling a bigger model does not lift it.

At 4k the truncation is SILENT, which is why `OLLAMA_CONTEXT_LENGTH = "32768"` sits in the
module. An agent harness spends around 8k tokens of FIXED prefix before reading a single
file (measured with DeepSeek Harness: 1051 tokens of system prompt plus 7128 of tool
definitions), so at 4k the prompt is cut before the task even arrives, and the model looks
stupid when it is merely blindfolded.

The price was measured and it is cheap: `qwen3.5` is 5.6 GB at 4k and 6.6 GB at 32k, so 28k
extra tokens of KV cache cost about 1 GB and it stays 100% on the GPU.
