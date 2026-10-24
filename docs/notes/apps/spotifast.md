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

## The theme: colors only, and a real file

`modules/home/apps/spotifast.nix` generates `~/.config/spotifast/themes/dotfiles.json` from
`my.theme.palette`, mapped like the spicetify "text" scheme it replaced: the background, the
surfaces and the green accent. It follows a `my.theme.name` switch on the next rebuild.

- **Colors only.** Upstream's format sets colors and keeps the app's fonts, so the mono, TUI-like
  look of spicetify's "text" theme did not come along. Accepted on 24/10/2026 for the RAM.
- **A copy, not a link.** The app skips symlinks in its themes folder, so `home.file` cannot own
  it; an activation installs the file instead, and the app notices the change on its own.
- **Picked once, by hand.** The choice lives in the app's own `settings.json`, which it rewrites,
  so it is not declared: Settings > Appearance > Theme > `dotfiles`. The fixed file name keeps that
  pick valid across palette switches. Turn off "Colour from album art" for fixed colors on every
  page.

## Playback goes through Soloist

Spotify refuses `librespot` the audio key for many accounts, new AND old (the log says
`error audio key 0 1`, then `Spotify refused the audio key`). Sign-in, the library and search all
work; only the sound is refused, and nothing on this machine changes that. It is upstream's open
[spotifast#283](https://github.com/crmne/spotifast/issues/283), on top of
[librespot#1649](https://github.com/librespot-org/librespot/issues/1649). It hit this account on
24/10/2026, on the first play.

The way around it keeps spotifast as the app: [Soloist](https://github.com/spotify/soloist),
Spotify's OFFICIAL headless Connect receiver, runs as a `--user` service
(`modules/home/apps/spotifast.nix`) and shows up in spotifast's device list under the hostname.
Spotifast picks it once and remembers the choice; Soloist gets its keys through Spotify's own
engine, so it plays. No Electron, no CEF.

- **Package.** [`pkgs/soloist/`](../../../pkgs/soloist/package.nix), the release binary, unfree.
  It links only glibc and libatomic and dlopens libpulse, which PipeWire answers.
- **It EXPIRES.** A build stops 90 days after it is made, exiting 10. The unit does not restart
  on 10; `update` (its bump reads the URL's Last-Modified) plus a rebuild does.
- **The API key.** Generated once in the Spotify for Developers dashboard (Soloist API Key page,
  Premium only), stored in Bitwarden as `Spotify Soloist API Key`, then `sync-secrets` and a
  rebuild. It reaches the unit as `SOLOIST_API_KEY` through the `soloist.env` template, and the
  unit does not exist until the vault holds the key.
- **Checking it.** `systemctl --user status soloist`, then the hostname in spotifast's devices.

## Around it

- **Media controls.** It registers MPRIS as `spotifast`, so `playerctl --player=spotifast`; the bar
  pill and the media panel match that name (`modules/home/desktop/quickshell/`).
- **Autostart.** The `spotifast` entry in `my.autostart` opens it with `--start-hidden`. Its own
  "start with computer" stays Off, or it becomes a second owner
  ([autostart.md](../desktop/autostart.md)).
- **Sign-in.** The grants go to the Secret Service (gnome-keyring), so a locked keyring means
  signing in again each session.

## What it replaced

The CEF client themed by spicetify (`spicetify-nix`), plus three overlays that existed only to
make CEF open: `--no-zygote`, the Wayland flag and a cleaner for a stale `SingletonLock`. All gone
on 24/10/2026. The 4145 restarts it caused in the autostart are kept as history in
[autostart.md](../desktop/autostart.md).
