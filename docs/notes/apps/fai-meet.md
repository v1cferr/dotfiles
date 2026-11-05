# fai-meet

Module: [`modules/home/apps/fai-meet.nix`](../../../modules/home/apps/fai-meet.nix)

The FAI.UFSCar meeting recorder: it records the microphone and the system sound on separate
tracks, and the server returns the transcript, the summary and the minutes as a Word file. Login
is the FAI Microsoft account. It is a Tauri app (Rust plus WebKitGTK).

## On demand, never installed

Run it with `fai-meet-latest`. Arguments after the name go to the app.

Until 05/11/2026 the repo installed the official AppImage, repackaged under `pkgs/fai-meet`. It
came out because **the system must update without the FAI VPN**. Everything about the AppImage
lives behind that VPN, starting with its only download URL, `meetings.sup.fai.ufscar.br`. A `gc`
dropped the AppImage from the store, the next nixpkgs bump changed `appimageTools`, and the
rebuild then had to download the AppImage again: off the VPN, the whole `upgrade` failed for an app
that cannot work off the VPN anyway, since it talks to that same server. Pinning the AppImage in
the closure would only have moved the dependency to the first fetch after every reinstall.

Going on demand costs one thing: the Microsoft login callback (`fai-meet://`) no longer has an
installed `.desktop` to land on.

## `fai-meet-latest`

The FAI Meetings repository builds the app from source and publishes it to the FAI's binary cache
(trusted in [`core.nix`](../../../modules/nixos/core/core.nix), see
[core](../repo/core.md#the-fai-meet-cache)). `fai-meet-latest` asks the API which commit was
published last (`/v1/desktop/latest`, field `nix.rev`) and runs that one, so it downloads in seconds
instead of compiling. It never follows `main`: a commit not yet published is not in the cache, and
the whole Rust build would run here. Reading the flake needs the FAI VPN and the SSH key on git.sup;
the binary itself comes from the cache.

The keyring the login is stored in is the session's gnome-keyring, already on: see
[`keyring.nix`](../../../modules/home/desktop/keyring.nix).
