# Spotifast: Spotify without a browser engine

Package [`pkgs/spotifast/`](../../../pkgs/spotifast/package.nix). Upstream: <https://github.com/crmne/spotifast>.

## Why it is here

The official client is CEF, a whole Chromium. Spotifast is native (Rust + egui), plays through
`librespot` and reads the library through the Web API. Upstream claims ~100 to 250 MB of RAM and
well under a second to open. Playback needs Premium; a Free account only browses.

## Why the release binary and not the flake

The same reasons, the same layout and the same bump as its sibling
[ZapFast](zapfast.md#why-the-release-binary-and-not-the-flake): the upstream flake has no binary
cache, so every bump would compile Rust (plus libprojectM for MilkDrop), while the
`x86_64-unknown-linux-gnu` tarball links only `libpipewire`, `libasound`, `libstdc++` and glibc
2.39. It is built WHOLE from unstable for the same glibc reason. Its wrapper adds `dbus` to the
dlopened list, which upstream's flake wraps too and ZapFast does not need.

`spotifast-portable.txt` is left out of the tarball, because it turns on the in-app updater, which
would try to rewrite the store. The `contrib/omarchy` hook is for another distro's theming.
