# antigravity-ide

Modules: [`pkgs/antigravity-ide/package.nix`](../../../pkgs/antigravity-ide/package.nix),
[`pkgs/antigravity-ide/bump.nix`](../../../pkgs/antigravity-ide/bump.nix),
[`modules/home/apps/antigravity-ide.nix`](../../../modules/home/apps/antigravity-ide.nix)

Google's agent-first editor, a VS Code fork. It is the desktop half of the suite whose terminal
half is [`agy`](antigravity-cli.md). Two decisions: where the bytes come from, and why its config
is not declared.

## unstable's recipe, Google's tarball

nixpkgs-unstable already packages it as `antigravity-ide` (`buildVscode`, the same builder as
VS Code), and that recipe is worth keeping: the Electron wrapping, the desktop entry, the FHS
variant. What lags is the src: on 22/11/2026 unstable carried 2.7.0 while Google shipped 2.8.0.

So it is the [VS Code](vscode.md) arrangement again: `overlayAntigravityIde` in
`flake/overlays.nix` keeps `unstable.antigravity-ide` and swaps only `version` and `src`, read
from `source.json`, the one file the bump writes. No GitHub release exists to track: the IDE is
closed source, and the tarball on Google's CDN is the official download.

## The bump reads the IDE's own update API

`bump.nix` asks the same endpoint the app's updater asks
(`antigravity-ide-auto-updater-…run.app/api/update/linux-x64/stable/latest`). Its answer
publishes the `sha256hash`, so a bump costs one small JSON and no download.

The trap is the version: the API's `version` field is a commit hash and `productVersion` is the
VS Code base (1.107.0), so neither is the release. The release only exists inside the url
(`/antigravity/stable/2.8.0-<build id>/`), and the bump parses it from there, as nixpkgs'
`update.js` does. If the API ever adds a real version field, that parse goes away.

The url carries a space (`Antigravity IDE.tar.gz`): the bump stores it as `%20`, and the
`fetchurl` gets an explicit `name`, since `%` is no store path character.

## Nothing under its config is declared

Same reasoning as VS Code's extensions: the app writes its own state (settings, the agent's
login, extensions) at runtime, and a store symlink there would break the first write. Until a
setting proves worth pinning, the package is the whole module.
