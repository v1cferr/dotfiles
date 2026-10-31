# fai-meet

Module: [`pkgs/fai-meet/package.nix`](../../../pkgs/fai-meet/package.nix)

The FAI.UFSCar meeting recorder: it records the microphone and the system sound on separate
tracks, and the server returns the transcript, the summary and the minutes as a Word file. Login
is the FAI Microsoft account. It is a Tauri app (Rust plus WebKitGTK), distributed only as
binaries from [the download page](https://meetings.sup.fai.ufscar.br/download/nixos), so the repo
repackages the official AppImage, the same pattern as [`curseforge`](curseforge.md).

## The pointer URL

The only Linux download is `download/linux/FAI-Meet.AppImage`; the versioned spellings
(`FAI-Meet-0.5.0.AppImage`, `0.5.0/FAI-Meet.AppImage`, `latest.json`) all answer 404, tested on
31/10/2026. So, like curseforge, the hash in `source.json` pins the content, the fetch breaks on a
cold store the day a new release lands, and the package stays OUT of the `packages` check.

[`fai-meet-bump`](../../../pkgs/fai-meet/bump.nix) pays that price on `update`. Asking "did it
change?" costs one HEAD request: the server names the release in the `Content-Disposition`
(`filename="FAI-Meet-0.5.0.AppImage"`), and only a new version pays the 84 MiB download.

## The internal self-updater does not work

The binary carries its own updater, which swaps the AppImage file in place. The store is
read-only, so updating is `update`/`upgrade`, like everything else.

## The login scheme is declared, not registered

The Microsoft login comes back through `fai-meet://`. The deep-link plugin tries to register
itself at runtime through `xdg-mime`, which fails on startup because `~/.config/mimeapps.list` is
managed by home-manager:

```text
/usr/bin/xdg-mime: line 1002: /nix/store/...-mimeapps.list.new: Read-only file system
```

So [`modules/home/apps/fai-meet.nix`](../../../modules/home/apps/fai-meet.nix) declares the
association, and the package's `.desktop` gets `%u` on its `Exec`, which upstream's lacks, so the
callback URL actually reaches the app.

## Known noise in the log

`libdconfsettings.so: undefined symbol: g_assertion_message_cmpint` comes from the session's
`GIO_EXTRA_MODULES`, built against a newer GLib than the one the AppImage bundles. GIO skips the
module and the app runs; it is cosmetic.

The keyring the login is stored in is the session's gnome-keyring, already on: see
[`keyring.nix`](../../../modules/home/desktop/keyring.nix).
