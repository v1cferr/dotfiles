# Gemini: a web app installed by Chrome's policy

`modules/nixos/desktop/web-apps.nix`. Upstream: <https://gemini.google.com/app>.

## Why a web app

Google's Gemini desktop app exists for macOS (15/04/2026) and Windows (10/09/2026) only. Nothing
for Linux in nixpkgs either: `nix search nixpkgs gemini` lists the gemini:// protocol browsers and
the CLIs. The "Gemini desktop" repos on GitHub are an Electron shell around the same site, with
their own login and one more third-party binary for no gain.

So the site, in a window of its own, from Chrome dev: the browser where the Google account is
already signed in.

## Why the policy, and not `--app=`

Measured on 04/11/2026, Chrome running under XWayland:

| Launch | Window class | Login |
| --- | --- | --- |
| `google-chrome-unstable --app=https://gemini.google.com/app` | `Google-chrome-unstable`: the window joins the running Chrome | shared |
| the same, with `--user-data-dir=<new> --class=gemini` | `gemini` | a second login, a second profile |
| an installed web app | its own (`crx_<id>`) | shared |

A class of its own is what the rest of the desktop keys on: the bar's icon (the `.desktop` entry's
`StartupWMClass`), window rules, the vault. Only the installed app has one without a second
profile.

`WebAppInstallForceList` installs it declaratively into the signed-in profile, merged into the same
managed policy JSON as the spellcheck keys (`/etc/opt/chrome/policies/managed/extra.json`, every
channel). Chrome itself writes the launcher entry and the icon into `~/.local/share/applications`
and `~/.local/share/icons`, which are state and already persisted. Removing the entry from the list
uninstalls the app at Chrome's next policy refresh.
