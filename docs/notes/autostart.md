# The autostart panel, and Spotify's 4145 restarts

`home/desktop/autostart.nix`. What OPENS along with the graphical session, in a single place. Edit
true/false in the panel plus `rebuild`. It mirrors the idiom of `system/services/toggles.nix`
(`mkEnableOption` plus a gate), but for GUI APPS.

## The index: what comes up at boot lives in three places

| Place | For what | Why separate |
| --- | --- | --- |
| `my.autostart` (here) | GUI apps with no service of their own: Discord, Spotify, LocalSend | LocalSend has a NixOS module, but only for the package and the firewall; what BRINGS IT UP is this panel |
| `my.services.<n>` | real services with a module or daemon (dropbox, jellyfin, ollama, sunshine, restic) | keys in `system/services/toggles.nix`, values in `hosts/<host>/services.nix` |
| `hypr/lua/autostart.lua` | session infrastructure that NEEDS the compositor's `exec-once`: hyprlock, quickshell, wl-clip-persist | only the compositor knows the right moment |

hyprlock is the interesting case: the TRIGGER is still the `exec-once`, but hyprlock itself is a
unit (`hyprlock.service`, see [`lockscreen.md`](lockscreen.md)), so boot, idle and the bar's button
all go through the same owner.

## Why a service and not `exec-once`

`exec-once` does NOT restart if the app dies. A systemd service does.

`Restart=on-failure` on purpose: a crash comes back, but CLOSING it by hand respects the decision.
With `always` you would not be able to close the app, since it would come back in seconds. (The
opposite call is made in [`dropbox.md`](dropbox.md), and for a stated reason.)

## The Spotify incident, and the correction it forced

A previous version of this comment said "(Electron exits with 0 when you close it)", and it WAS
FALSE, at least for Spotify, which is not Electron but CEF.

What actually happens, MEASURED: `bin/spotify` moves the real process into a scope of its own
(`app-org.chromium.Chromium-<pid>.scope`, OUTSIDE the unit's cgroup) and the process systemd
follows EXITS WITH 1, always, even when the app came up perfectly.

The result with `Restart=on-failure`: systemd reads "it failed", restarts in 5 s, the new launcher
finds the live instance, prints "Opening in existing browser session", MAKES THE WINDOW SHOW UP and
exits 1 again. An infinite loop. Measured in one day's journal: **4145 restarts**, ~200 ms of CPU
each, and the Spotify window popping up on the screen by itself, which is how the problem showed
up at all.

Two defenses came out of it:

1. **`successExit` per app.** For Spotify, exiting 1 IS the normal path, and declaring that makes
   the unit finish clean instead of "failed", so it does not restart. The price, stated explicitly:
   a crash with code 1 does not come back either. Acceptable because, having escaped the cgroup,
   systemd ALREADY does not supervise the real process. The unit here is a launcher, not a
   supervisor, and it is honest to say so.
2. **`StartLimit` on ALL the units**: at most 3 starts in 5 min. If this ever goes back into a
   loop, the unit DIES and stays visible in `systemctl --user --failed`, instead of running 4145
   times in silence. The root cause of the damage was not just the exit code, it was that there was
   no limit at all: with `RestartSec=5` it made 2 starts per 10 s, always under the default
   `burst=5`, so the factory brake never got to act.

## The per-app notes

**Discord**: the binary is `Discord`, capitalized, which is what its own `.desktop` uses.

**LocalSend**: `--hidden` comes up WITHOUT a window, only the tray icon, which is what makes sense
for a receiver: LocalSend only RECEIVES a file if it is open, and sending from the phone cannot
require walking to the PC to open the app.

- WARNING: the bar's tray becomes the ONLY way to bring the window back. If the bar is not up, it
  keeps running invisible.
- WARNING: do NOT turn on "Autostart after login" in THE APP's settings. That writes a `.desktop`
  into `~/.config/autostart` and would become a SECOND owner of the same automation (rule 15), with
  two instances fighting over port 53317.
- The binary is `localsend_app`, and the package comes from the MODULE's option rather than
  `pkgs.localsend`: if it ever becomes `unstable.localsend` in `system/`, the autostart follows on
  its own. It is the Spotify trap solved by construction instead of by attention.

**Spotify**: `unstable.*` has to MATCH `home/packages.nix`, otherwise the autostart brings up the
broken version from the base while the menu opens the good one. The `--no-zygote` flag that keeps
the app standing does NOT come from here: it belongs to the PACKAGE, baked in by `flake.nix`'s
`overlaySpotifyNoZygote`, so the menu (`Exec=spotify` through the PATH) gets the same flag as this
autostart. A single owner, rule 15.

## Where the packages come from

`home/packages.nix`, except LocalSend, whose owner is `system/net/localsend.nix` (the nixpkgs
module ties package and firewall together). Here we only REFERENCE the binary by store path, so it
is not installed again and rule 4 holds.
