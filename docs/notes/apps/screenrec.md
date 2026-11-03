# Screen recording: the Flameshot flow, for video

`modules/home/apps/screenrec.nix`. wl-screenrec from the UNSTABLE channel plus three scripts:
`screenrec-toggle`, `screenrec-start` and `togif`. The binds (SUPER+SHIFT+R and the "screenrec"
submap) live in `modules/home/desktop/hypr/lua/keybinds.lua`.

## The flow

SUPER+SHIFT+R with nothing recording enters the submap: `1` records the main monitor, `2` the
secondary (both by NAME from `my.monitors`, never by position), `R` a region drawn with slurp, Esc
leaves. SUPER+SHIFT+R again stops it. The file lands in `~/Videos/Recordings` as an H.264 MP4, and
the notification offers "Open folder" and "Convert to GIF". `togif <file.mp4>` does the same from
the terminal. There is no audio, by choice: screen clips, not screencasts.

The running recording is `$XDG_RUNTIME_DIR/screenrec` (PID, then path). Stopping is SIGINT, which
lets wl-screenrec write the MP4 index; SIGKILL leaves a file with no `moov` atom that plays nowhere.

## Why wl-screenrec

- **Not OBS**: too much tool for a 10-second clip.
- **Not gpu-screen-recorder**: its fast path is KMS capture, and KMS capture does not run on `xe`
  (the same wall Sunshine hit). Its other path is the portal.
- **Not Kooha or anything portal-based**: the portal asks which screen EVERY time, which defeats a
  keyboard flow.
- **wl-screenrec** captures through the compositor's own copy protocol, takes `-o <name>` and
  slurp's `-g` directly, and encodes on the Arc through VA-API (iHD, set in
  `modules/nixos/hardware/intel-arc-b580.nix`). `--low-power=off` because the Arc has no low-power
  H.264 entrypoint, so `auto` only prints a warning before falling back.

## Pitfalls found on the way

- **The stable 0.2.0 crashes on a rotated output.** DP-2 is portrait (`transform 1`), and 0.2.0
  builds a broken filter graph (`1080transpose_vaapi=dir=clock`, a missing comma) and panics. 0.3.2
  from unstable records it fine, hence `unstable.wl-screenrec`.
- **No "whole layout".** wl-screenrec refuses a region that crosses two outputs ("not entirely
  within one output, bailing"), so there is no "all" key, and a slurp region dragged across both
  monitors fails with a red `hyprctl notify`. With a portrait monitor beside a landscape one, a
  combined video would be mostly black bars anyway.
- **LD_LIBRARY_PATH from the shell.** The interactive zsh exports alsa/pipewire built on a newer
  glibc, and any ffmpeg-linked store binary run from the terminal dies with
  `GLIBC_2.43 not found`. Every script unsets it first; the keybind path never had it.
- **The GIF caps the LONGER side.** Capping only the width gave the portrait DP-2 a 1707 px tall
  GIF of 22 MB for 3 seconds. Fitting both sides into 960 (never upscaling a small region) cut it to
  7 MB.
