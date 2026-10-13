# LibreWolf

`modules/home/apps/librewolf.nix`. The browser plus the palette on its frame. It is the second
browser here, used little, so the theme is the smallest thing that holds, not a project like Zen's.

## Why userChrome and not a theme add-on

A static theme WebExtension is Mozilla's supported way to color the frame, and it was the first
plan. It does not survive LibreWolf's add-on rules: an add-on built here is unsigned, and loading it
means `xpinstall.signatures.required` off for EVERY add-on, not just this one. nixpkgs' own
`nixExtensions` path pays for that by blocking every add-on not declared in Nix, which would drop uBlock
(installed by LibreWolf's own policy) and Dark Reader (installed by hand). Weakening a privacy browser's add-on checks for a color is
the wrong trade, so the theme is a `userChrome.css`, which needs no signature at all.

The pref that makes Gecko read it, `toolkit.legacyUserProfileCustomizations.stylesheets`, is a
`defaultPref` in the PACKAGE (`librewolf.override { extraPrefs }`), so the profile gets no `user.js`
of ours. The override only rewraps: LibreWolf's own policies (uBlock, the add-on rules) still land,
merged under it, measured in the built `policies.json`.

## The variables, measured in LibreWolf 157 (13/10/2026)

The theme API's names, `--lwt-*`, `--toolbar-bgcolor`, `--arrowpanel-*`, are no longer read: a sheet
setting all of them changed nothing on screen. What paints each part was read with
`InspectorUtils.getMatchingCSSRules` in a throwaway profile under Marionette (the same client as
Zen's lab, [`lab.py`](../../../modules/home/apps/zen/lab.py), on port 2830):

| Part | Variable | Palette |
| --- | --- | --- |
| nav bar | `--toolbar-background-color`, `--toolbar-text-color` | surface, text |
| selected tab, hover | `--tab-background-color-selected`, `--tab-background-color-hover` | surface, track |
| address bar | `--toolbar-field-background-color`, `-border-color`, `-text-color` | bg, border, text |
| address bar focused | `--urlbar-background-color-focus`, `--toolbar-field-text-color-focus`, `--focus-outline-color` | bg, text, accent |
| menus and popups | `--panel-background-color`, `--panel-text-color`, `--panel-border-color` | surface, text, border |
| the frame behind the tabs | none: `#navigator-toolbox` itself | bg |

The frame has no variable because Linux paints it with the system's `-moz-headerbar` color.

**When an update breaks it**, the symptom is a gray part. Open a lab profile with `--marionette`, run
`getMatchingCSSRules` on that element, and swap in the new name; that is how this table was made.

## The profile

LibreWolf picked a random directory under `~/.config/librewolf/librewolf/`. The activation reads it
from `profiles.ini` and links `chrome/userChrome.css` into it, like Zen's; no profile yet means
nothing to link, and the next activation does it. A running LibreWolf picks the sheet up on restart.
