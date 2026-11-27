# Live Captions: English captions for any audio on the desktop

`modules/home/apps/livecaptions.nix`, the window rule in `hypr/lua/rules.lua`, the toggle in
`hypr/lua/keybinds.lua` (SUPER+SHIFT+C).

## Why this one

The goal is reading English speech live (streams, videos, calls) without depending on the
browser. [LiveCaptions](https://github.com/abb128/LiveCaptions) (GPL-3.0-or-later) listens to
the default output through PipeWire and transcribes with aprilasr, a small streaming model that
runs on the CPU and writes word by word with almost no delay. The nixpkgs wrapper pins
`APRIL_MODEL_PATH` to the English model in the store, so nothing is downloaded.

What lost, measured on 27/11/2026:

| Option                                    | Why not                                                                                      |
| ----------------------------------------- | -------------------------------------------------------------------------------------------- |
| Local Live Captions (Firefox add-on)      | Far slower and less accurate: Firefox ships no WebGPU on Linux, so its model runs on the CPU |
| Chrome Live Caption                       | Chrome is not used here, and it only hears its own tabs                                      |
| Translating add-ons (CaptionGo and peers) | Closed source, cloud or paid                                                                 |

## Limits

- **English only, no translation.** A pt-BR line would need a separate cascade (whisper.cpp on
  the Arc through Vulkan, then a model in Ollama), and it would trail the speech by 2 to 4 s.
- Accuracy drops with music, crosstalk or slang, as with any ASR.

## The window

The main window (title `Live Captions`) floats, is pinned to every workspace and never takes
focus when it opens. Its settings window shares the class, so the rule also matches the title.

The size is fixed in the rule (`1030 110`) because the window is born at 1222x194 and shrinks
after the rule runs. With `window_w` in the `move` expression, the strip landed off center. The
strip opens at the bottom center of the FOCUSED monitor, including the portrait one.

SUPER+SHIFT+C closes the window when it is up, which ends the process, and launches it
otherwise. The model loads in about a second, so there is no hidden mode to keep.

`installed-models` is reset through dconf: an old Flatpak install had left a `/app/...` path
there, which logged `aam: failed to read file` at every launch.
