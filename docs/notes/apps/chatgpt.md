# ChatGPT: the official desktop app

`modules/home/apps/chatgpt.nix`, package [`pkgs/chatgpt/`](../../../pkgs/chatgpt/package.nix)
(an override of nixpkgs `pkgs/by-name/ch/chatgpt`). Upstream: <https://chatgpt.com/download>.

## Why it is here, and why this build

OpenAI shipped an official Linux build on 11/08/2026, in public preview: one Electron app with
ChatGPT, ChatGPT Work and Codex, as .deb and .rpm. nixpkgs-unstable packages that binary
(unfree, three maintainers, its own `update.sh`); stable still lists it for Darwin only.

## Always the newest build: unstable's recipe, OpenAI's src

The channel alone trails: on 03/11/2026 the lock gave 26.1013, nixpkgs master had 26.1027 and
OpenAI's apt repo already 26.1029. So it follows VS Code's shape (layer 3): `flake/overlays.nix`
keeps nixpkgs' recipe (the wrapper, the launcher, the Codex wiring) and swaps only
`passthru.source`, which is where that recipe reads version and src from.

`chatgpt-bump` (its `passthru.updateScript`, run by `update`/`upgrade` through vendored-bump, see
[docs/notes/repo/version-bumps.md](../repo/version-bumps.md)) reads the repo's `Packages` index:
`Version`, `Filename` and the published `SHA256`, so a no-op costs one small download and a bump
never downloads the 200 MB .deb to hash it.

If a new build changes its layout and nixpkgs' recipe breaks on it, the fix is the recipe's next
version: `nix flake update nixpkgs-unstable`, or pin source.json back until the channel catches up.

What was weighed on 03/11/2026, and why each lost:

- Community flakes that repack the official .deb (danielbodart, cgumb/poeck, B-Shinchan): the
  same binary, one more third-party input, no gain over nixpkgs.
- Ports that convert the macOS DMG (ilysenko/codex-desktop-linux, EricKrouss/chatgpt-desktop-linux):
  made before the official build existed, an unofficial repack of a proprietary app.
- A web app (`chromium --app=https://chatgpt.com`): the most robust, but no Codex and no desktop
  features. The fallback if the preview breaks.
- WinBoat (Windows in a container, shown through RemoteApp): a whole Windows VM for one Electron
  app, still beta, with thin NixOS reports.

## The Codex CLI

The app runs Codex through a CLI binary. The package's `codex` argument is overridden with
`pkgs.codex` (pkgs/codex, the official release), the one `modules/home/shell/codex.nix` installs,
so the wrapper's `CODEX_CLI_PATH` and the terminal use the same version and the same
`~/.codex/config.toml`.

## Daily chats: the tabbed web launcher

"ChatGPT (tabs)" (`chatgpt-web`, same module) opens chatgpt.com in the guarded Zen on its own
profile, `~/.local/share/chatgpt-web`. The app stays for Codex; plain chats live in browser tabs.

Why, measured on 08/11/2026 with 26.1029:

- The app is Electron (Chromium 156) on OpenAI's `owl` runtime: a 715 MB `app.asar`, a 329 MB
  binary, and 22 processes holding about 1.6 GB RSS with a few chats open.
- Long chats lag because the whole conversation stays in the DOM and is re-rendered as tokens
  stream in; Codex, computer use and plugins load with it even when unused.
- It has no tabs and OpenAI has not announced any. A browser gives tabs, session restore and
  side-by-side windows for free, on the same subscription and history.

How it fits the rest of the desktop:

- `--name chatgpt-web` is the Wayland app_id, so `vault.lua` hides it on lock through its
  `chatgpt` pattern, and it never matches `^zen`.
- It runs through `my.zen.package`, so the launch guard still applies and closes it on a long lock.
  This profile has NO primary password of its own: the chatgpt.com session cookie is protected
  only by the guard and the vault, the same as the app's.
- Extensions that virtualize long chats (render only the messages in view) fix most of the lag,
  but they read every page on chatgpt.com. Install one by hand into this profile only after
  auditing its source; none is declared here.

## Known limits (preview)

- OpenAI tests only Ubuntu, Debian and Fedora.
- Computer use works only inside the app's own browser.
- Early reports of input-method and scaling problems on Wayland.
