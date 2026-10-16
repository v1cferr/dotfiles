# SignalSift: my content intelligence daemon

`modules/home/services/signalsift.nix`. [SignalSift](https://github.com/v1cferr/signal-sift)
follows the blogs, newsletters, channels and podcasts I care about, transcribes what has no
captions, scores every segment against my interests with a local LLM, and serves the result on
<http://127.0.0.1:7878/> (a web UI and an HTTP API). The app lives in its own repo; this module is
only the DEPLOY, pinned by the `signal-sift` flake input.

## Why a user service, from the app's own module

- The daemon needs no privilege: it reads public content and writes under my XDG directories. So it
  is a systemd **user** unit started with my session, not a system service.
- The unit comes from the app's Home Manager module (`homeManagerModules.default`), not from a unit
  written here: the hardening, `Nice=10`, CPU/IO weight 20 and `MemoryMax=10G` are decided and
  measured in the app's repo (its `deploy/nixos/README.md` and ADRs 0008 and 0011).
- No `inputs.nixpkgs.follows` on the input: the package and the Vulkan builds of whisper.cpp
  and llama.cpp come from SignalSift's own lock, the exact store paths it benchmarked, even though
  this repo is on nixos-26.05.

## GPU only

Speech recognition and the LLM run on the Arc B580 or not at all (`runtime.require_gpu`, stated
in the module even though it is the default). Both engines silently fall back to the CPU when Vulkan
fails; the app kills such a run and retries the job later instead. MEASURED on 15/10/2026 on this
machine: CPU whisper is about 11 times slower than Vulkan and keeps all six cores busy. ffmpeg and
yt-dlp stay on the CPU, since decoding audio and downloading are not inference.

## The models are declared

The three model files are `fetchurl`s with their SHA-256, the same files the app's benchmarks
used, so a reinstall needs no manual download (rule 3). On 16/10/2026 they were added to the store
from the copies already on disk (`nix-store --add-fixed sha256`), so the first build fetched
nothing. The other models in `~/.local/share/signalsift/models` were only for the benchmarks.

| File | Use | Size (MEASURED 16/10/2026) |
| --- | --- | --- |
| `ggml-large-v3-turbo-q5_0.bin` | speech recognition | 547 MiB |
| `ggml-silero-v5.1.2.bin` | voice activity detection | 0.8 MiB |
| `gemma-4-E4B_q4_0-it.gguf` | summaries and relevance | 4.8 GiB (4916 MiB) |

## The interest profile is here

`signalsift-interests.toml` is versioned in this repo, so a change to what I find relevant has a
commit. Only analyses made after an edit use the new text; the app stores a fingerprint of the
profile with every score.

## Not declared: the sources

The feeds and channels live in the app's database, not in Nix, because poll state, history and my
feedback are attached to them (rule 6). After the first switch, once:

```sh
signalsift doctor
signalsift sources import ~/Projects/GitHub/v1cferr/signal-sift/config/sources.example.toml
```

## Rejected

- **A unit written here**: it would duplicate the hardening and limits the app already owns and
  measures (rule 14).
- **Following this repo's nixpkgs**: nixos-26.05 would rebuild the engines at versions nobody
  benchmarked.
- **Models downloaded by hand**: a manual step a reinstall would forget (rule 3).
