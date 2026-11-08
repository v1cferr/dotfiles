# Web apps: one list, two engines

`my.webApps` in `modules/nixos/desktop/web-apps.nix` is the SSOT; `modules/home/apps/web-apps.nix`
reads it through `osConfig` for the Zen side.

## Why web apps

The vendors' desktop apps for these services are a Chromium of their own (Electron or worse) and
add little over the site. Measured on 08/11/2026: the ChatGPT app is 22 processes and about
1.6 GB RSS ([chatgpt](chatgpt.md)); Gemini has no Linux app at all ([gemini](gemini.md)). A site
inside a browser that is already running costs a tab or a window, not another runtime.

This is a stopgap, not a verdict on desktop apps. Discord's CTO confirmed on 04/11/2026 a full
rewrite of its client in Rust (GPUI, not Electron or Tauri), with an internal build reported at
about 290 MB and a 1 s start. A native app built that way would beat any web app here; when one
ships for a service on this list, it replaces the entry.

## Why two engines

|                | `chrome`                                       | `zen`                                    |
| -------------- | ---------------------------------------------- | ---------------------------------------- |
| How            | `WebAppInstallForceList` policy installs a PWA | `<name>-web` launcher on its own profile |
| Tabs           | no, one window per app                         | yes, with session restore                |
| Login          | the signed-in Chrome profile                   | its own, done once                       |
| Wayland app_id | `chrome-<id>-Default`                          | `<name>-web`                             |
| Launcher entry | written by Chrome (state)                      | declared by home-manager                 |

Pick `chrome` when the account already lives in Chrome and one window is enough (Gemini). Pick
`zen` when tabs matter (ChatGPT: several chats at once).

## Rules for a new entry

- The app_id must be one `vault.lua` can match without also matching `^zen`; `<name>-web` does it
  when `<name>` is already a pattern there. Otherwise add the pattern to `vault.lua` by hand: the
  Lua stays static for hot reload, so it is not generated from this list.
- A Zen profile has NO primary password. Its session is protected by the launch guard (it closes
  Zen after a long lock, see [zen](zen.md)) and by the vault, not by Zen's password prompt.
- A Chrome PWA only appears while Chrome runs, about 20 s after start. Never launch Chrome with
  a scratch `--user-data-dir` to test one: Chrome writes the launcher entry with that path, and the
  real one is overwritten (that broke Gemini's launcher from 04/11 to 08/11/2026).
