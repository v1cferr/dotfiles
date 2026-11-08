# Gemini: a web app installed by Chrome's policy

An `engine = "chrome"` entry of `my.webApps` (`modules/nixos/desktop/web-apps.nix`, see
[web-apps](web-apps.md)). Upstream: <https://gemini.google.com/app>.

## Why a web app

Google's Gemini desktop app exists for macOS (15/04/2026) and Windows (10/09/2026) only. Nothing
for Linux in nixpkgs either: `nix search nixpkgs gemini` lists the gemini:// protocol browsers and
the CLIs. The "Gemini desktop" repos on GitHub are an Electron shell around the same site, with
their own login and one more third-party binary for no gain.

So the site, in a window of its own, from Chrome dev: the browser where the Google account is
already signed in.

## Why the policy, and not `--app=`

Measured on 04/11/2026:

| Launch                                                       | Window class                                                  | Login                            |
| ------------------------------------------------------------ | ------------------------------------------------------------- | -------------------------------- |
| `google-chrome-unstable --app=https://gemini.google.com/app` | `Google-chrome-unstable`: the window joins the running Chrome | shared                           |
| the same, with `--user-data-dir=<new> --class=gemini`        | `gemini`                                                      | a second login, a second profile |
| an installed web app, under XWayland                         | still `Google-chrome-unstable`                                | shared                           |
| an installed web app, native Wayland                         | `chrome-<id>-Default`                                         | shared                           |

A class of its own is what the rest of the desktop keys on: the bar's icon (looked up by the
class among the `.desktop` entries), window rules, the vault. Only the installed app, under
Wayland, has one without a second profile.

**Only under native Wayland.** The first three rows ran under XWayland, and there the installed
app turned out no better: `crx_<id>` goes into WM_CLASS's instance, Hyprland keys on
its class, and the class stays `Google-chrome-unstable`. Under Wayland the app's `app_id` is
`chrome-<id>-Default`, the very name of the `.desktop` file Chrome writes, so the bar finds its
icon. Chrome 158 fell back to XWayland despite the wrapper's `--ozone-platform-hint=auto` (set
by `NIXOS_OZONE_WL`), so `modules/home/packages.nix` passes `--ozone-platform=wayland` through
the package's `commandLineArgs`.

**Chrome applies the policy only while it runs.** The rebuild only writes the JSON; the app
appeared about 20 s after Chrome started (Gemini's id: `gdfaincndogidkdcdkhapmbffkckdkhn`).

`WebAppInstallForceList` installs it declaratively into the signed-in profile, merged into the same
managed policy JSON as the spellcheck keys (`/etc/opt/chrome/policies/managed/extra.json`, every
channel). Chrome itself writes the launcher entry and the icon into `~/.local/share/applications`
and `~/.local/share/icons`, which are state and already persisted. Removing the entry from the list
uninstalls the app at Chrome's next policy refresh.
