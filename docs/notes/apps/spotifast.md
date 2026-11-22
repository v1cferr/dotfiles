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
Spotify's OFFICIAL headless Connect receiver, gets its keys through Spotify's own engine, so it
plays. Since 0.15 spotifast downloads Soloist from Spotify's CDN and runs it as a CHILD process
(Settings > Spotify Soloist), named `Spotifast Soloist (<id>)`. No Electron, no CEF, and nothing
in the repo: no package, no unit, no secret.

- **Why not our own.** From 24/10 to 22/11/2026 the repo vendored Soloist and ran it as a
  `--user` unit, because spotifast could not yet. Spotifast cannot attach to an external one, so
  that unit became a duplicate and was removed. The built-in one also ends two chores: a build
  EXPIRES 90 days after it is made, and spotifast fetches the new ones itself (falling back to
  the last build that worked), so neither a daily bump nor an expiry warning is needed.
- **The trade.** The PC is a Connect speaker only while spotifast runs (the autostart opens it
  hidden), and the binary lives outside the store, under `~/.local/state/spotifast/soloist/`
  (`builds/` for the binaries, `accounts/<hash>/` for the session and `soloist-output.log`).
- **Silent until it finds PipeWire.** The downloaded binary looks for PipeWire's `client.conf`
  only in `/etc/pipewire`, `/usr/share/pipewire` or `$PIPEWIRE_CONFIG_DIR`, and NixOS has none of
  them. It then logged `Pipewire initialization failed!!` (only with `-v`), played into a dummy
  driver and paused 20 ms after every play (22/11/2026). The package's wrapper sets
  `PIPEWIRE_CONFIG_DIR`, and the child inherits it.
- **The API key.** Generated once in the Spotify for Developers dashboard (Soloist API Key page,
  Premium only) and pasted into spotifast's setup, which keeps it in the Secret Service. The
  Bitwarden item `Spotify Soloist API Key` stays as the copy to paste again.
- **Pairing is ONE time, from the phone.** Spotifast's guide pairs through the desktop app, which
  this machine does not have; the phone's Spotify app does the same over ZeroConf. Soloist's
  ZeroConf port is random per start (no flag fixes it) and closed to the LAN, so it is opened only
  for that minute (`iptables -I nixos-fw -p tcp --dport <port> -j nixos-fw-accept`, then `-D`),
  with the port read from `ss -lntp` for the child's PID. The login lands in its `accounts/`
  folder and survives restarts, so after that no inbound port is needed.
- **Checking it.** `soloist-output.log` says `logged in as <user>`, and spotifast leaves the
  "Waiting for Spotify..." step.

## Around it

- **Media controls.** It registers MPRIS as `spotifast`, so `playerctl --player=spotifast`. The
  shell no longer matches that name: it shows and drives whichever player most recently started
  playing ([quickshell.md](../desktop/quickshell.md#audio-and-media)).
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
