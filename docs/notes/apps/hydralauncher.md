# hydralauncher

Modules: [`pkgs/hydralauncher/package.nix`](../../../pkgs/hydralauncher/package.nix),
[`modules/home/apps/hydralauncher.nix`](../../../modules/home/apps/hydralauncher.nix)

[Hydra](https://github.com/hydralauncher/hydra) is a game launcher with its own BitTorrent client,
an Electron app (MIT). The repo repackages the official AppImage, the same pattern as
[`stack-wallet`](crypto.md) and [`curseforge`](curseforge.md).

## Why not nixpkgs' `hydralauncher`

On 01/11/2026 the stable channel had 3.9.5 and unstable 4.1.6, while upstream was on 4.3.0. The
user wants it on the latest release, so it lives on the third layer of the version strategy:
[`hydralauncher-bump`](../../../pkgs/hydralauncher/bump.nix) runs on every `update`, see
[version bumps](../repo/version-bumps.md).

The bump costs two small requests and no download: the redirect of `/releases/latest` gives the
tag, and electron-builder's `latest-linux.yml` in that release carries the AppImage's sha512 in
base64, which is already the body of the SRI hash. The URL is versioned, so the package stays in
the `packages` check, unlike curseforge.

## Python inside the sandbox

The AppImage bundles `umu-run`, which Hydra uses to start Windows games through Proton. It is a
`#!/usr/bin/env python3` zipapp, and the AppImage FHS ships no Python, so the package adds
`python3` through `extraPkgs`.

## The internal self-updater does not work

electron-updater swaps the AppImage file in place, and the store is read-only. Updating is
`update`/`upgrade`, like everything else.

## The login scheme is declared, not registered

The `.desktop` claims `x-scheme-handler/hydralauncher`, but `~/.config/mimeapps.list` is managed
by home-manager, so the default is declared in the module instead of being left to the app.
State lives in `~/.config/hydralauncher`, listed in [`persistence.nix`](../../../modules/home/persistence.nix).
