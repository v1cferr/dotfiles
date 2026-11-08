# ChatGPT: a web app, and the desktop app that left

`my.webApps.chatgpt` in `modules/nixos/desktop/web-apps.nix` (an `engine = "zen"` entry, see
[web-apps](web-apps.md)). Upstream: <https://chatgpt.com>. Codex is the CLI: [codex](codex.md).

## What runs

"ChatGPT" in the launcher runs `chatgpt-web`: chatgpt.com in the guarded Zen, on a profile of its
own (`~/.local/share/chatgpt-web`), with tabs. The launcher icon is the SVG from
homarr-labs/dashboard-icons (Apache-2.0), pinned by commit, because the icon theme has none.

- `--name chatgpt-web` is the Wayland app_id, so `vault.lua` hides it on lock through its
  `chatgpt` pattern, and it never matches `^zen`.
- It runs through `my.zen.package`, so the launch guard still applies and closes it on a long lock.
  This profile has NO primary password of its own: the chatgpt.com session cookie is protected
  only by the guard and the vault.
- Spellcheck comes from the Gecko layer (`spellchecker.dictionary`), like any Zen profile.
- No extension, on purpose (audited 08/11/2026). chatgpt.com now virtualizes the conversation
  list itself, which is why GPT-Conversation-Toolkit (open, MIT, clean audit, but unsigned for
  Firefox) deprecated its lag fix. Speed Booster Toolkit (signed on AMO) is closed, minified,
  freemium through Freemius, and offers a cloud sync to its vendor. Add one only if this profile
  is MEASURED lagging: compare `document.querySelectorAll('[data-message-id]').length` with the
  chat's message count to see whether the virtualization is on.

## Why the desktop app left (08/11/2026)

OpenAI shipped an official Linux build on 11/08/2026, in public preview: one app with ChatGPT,
ChatGPT Work and Codex. It was here from 03/11 to 08/11/2026, on unstable's recipe with OpenAI's
newest .deb. Measured with 26.1029 before it went:

- Electron (Chromium 156) on OpenAI's `owl` runtime: a 715 MB `app.asar`, a 329 MB binary, and
  22 processes holding about 1.6 GB RSS with a few chats open.
- Long chats lagged. The lag-fix extensions blame the whole conversation staying in the DOM, but
  chatgpt.com virtualizes that list now, so the app's own load is the likelier cause: Codex,
  computer use and plugins start with it even when unused.
- No tabs, and OpenAI has not announced any.
- No tray and no start-hidden flag, so autostart needed a compositor hack to keep login windowless.
- At launch it wrote its own MCP server, marketplaces and plugins into `~/.codex/config.toml`, with
  store paths tied to its version (why Codex's config became a system layer: [codex](codex.md)).

The chats moved to the web app with tabs, and Codex was already the CLI, so the app was only cost.
It took with it `pkgs/chatgpt` and its overlay, the autostart entry and its hide marker, and the
Electron spellcheck seed, each of which existed only for it. Its blocks were cut from the live
`~/.codex/config.toml` the same day.

**Coming back** is the 03/11 shape in git history: `pkgs/chatgpt` (unstable's recipe, the src
from OpenAI's apt repo, bumped by `update`) plus a module passing `pkgs.codex` to `.override`.
Worth it only if the app gains something the web and the CLI lack, or ships native: Discord's
move from Electron to Rust ([web-apps](web-apps.md)) is the kind of change that would.
