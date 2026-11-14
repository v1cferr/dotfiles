# Pear Desktop: the YouTube Music client

`modules/home/apps/youtube-music.nix`, package `pkgs.unstable.pear-desktop` from nixpkgs. Upstream:
<https://github.com/pear-devs/pear-desktop> (formerly th-ch/youtube-music).

## Why it is here

YouTube Music in a native window, with its own MPRIS player, so the shell's media surfaces (the
island, the Control Center, the media panel and the bar) show and drive it like any other player.
Spotifast stays for Spotify and the `yt*` mpv aliases in `media.nix` stay for the CLI: three
different jobs.

Compared before adoption (11/2026) and not picked: YTMDesktop, YTMDesktop2, Limusic and SimpMusic.

## Where the package comes from

| Source               | Version (13/11/2026) | Picked |
| -------------------- | -------------------- | ------ |
| nixpkgs 26.05        | 3.11.0               | no     |
| nixpkgs-unstable     | 3.12.0               | yes    |
| upstream latest tag  | 3.12.0               | n/a    |

Unstable is step 2 of the [README's ladder](../../../README.md#where-does-it-come-from): stable lags
a release, and a YouTube Music wrapper breaks when the site changes, so the newest release is the
one that keeps working. The lock did not move to get it: the pinned unstable already carried
3.12.0. It is a cache hit (no local Electron build), MIT, with no `knownVulnerabilities`, and it
runs on nixpkgs' Electron 44, not a downloaded binary. Bumps come with `update`, like every
unstable package.

`youtube-music` is only a rename alias in nixpkgs and warns at evaluation (rule 21), so the module
names `pear-desktop`.

## Wayland: nothing to add

The nixpkgs wrapper already passes `--ozone-platform-hint=auto`, the Wayland decorations and the
text-input IME flags whenever `NIXOS_OZONE_WL` and `WAYLAND_DISPLAY` are set, and
`modules/nixos/desktop/desktop.nix` sets `NIXOS_OZONE_WL=1` for the session. So no wrapper, no
flags file. The `.desktop` is `com.github.th-ch.youtube-music.desktop`, the same string as the
Wayland `app_id`, which is what the shell matches to find the window.

## What it does not get

- **No autostart**: it opens by hand. If it ever should, it goes in `my.autostart`
  (`modules/home/desktop/autostart.nix`), never in the app's own "start at login" (rule 15).
- **No API server**: the `api-server` plugin is off by default and stays off, so no local port.
