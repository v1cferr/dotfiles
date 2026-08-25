# Dropbox: the tray icon, and 10 days of syncing nothing

`home/apps/dropbox.nix`. The `~/Dropbox` folder synced (the Obsidian vault plus documents).

A conscious exception to the "`home/` does not install" rule: `services.dropbox` is a USER SERVICE
(`systemd --user`), not a package in `environment.systemPackages`. The home-manager module already
brings `dropbox-cli` and starts the daemon, so here it is only ENABLED.

**Why the official client and not Maestral**: home-manager has an official maintained module for
this one. Maestral was archived upstream, has no module, and has a known bug on NixOS where it
loses its config on logout (nixpkgs#307898).

The intended use is only Obsidian `.md` notes and documents (the free plan, 2 GB): no binaries, no
large files. The restic repo does NOT come here.

**First use or RE-linking**: the daemon prints a URL to authorize in the browser.

```sh
dropbox-hm status   # copy the link and authorize
```

Do NOT use plain `dropbox status`; see the wrapper below. The client downloads its own binary into
`~/.dropbox-dist` (state, outside Nix), which is the imperative part Dropbox imposes; the rest is
declared.

## The incident this file exists not to repeat

Discovered on 11/08/2026: the daemon had been `active (running)` for 6 h, with not one error line,
and UNLINKED since ~01/08 (`unlink.db` rewritten; the hostkeys and `sync_history.db` frozen on
31/07). Ten days syncing NOTHING, with the service declaring itself healthy.

Two independent causes, each with its own remedy:

1. systemd did NOT notice the daemon dying → `ExitType`/`Restart`
2. NOTHING noticed the "alive but unlinked" → the healthcheck timer

## Why `dropbox-hm` exists

The daemon runs with its OWN HOME (`~/.dropbox-hm`), a decision of the home-manager module and not
of this repo. And the CLI only finds the daemon's socket if it inherits the SAME HOME: in a normal
shell, `dropbox status` answers "Dropbox isn't running!" with the daemon alive right next to it.

That LIE is what makes diagnosing by hand go wrong, and it is how the incident above went
unnoticed. The wrapper does not reinstall `dropbox-cli`; it references the module's SAME store
path, the way autostart does with LocalSend, so it does not break rule 4.

## The tray icon, and what it costs

The home-manager module pins an EMPTY `DISPLAY=` on the unit, on purpose: to it, this is a
headless daemon. The price is having no tray icon, MEASURED on 11/08/2026 on the live process:
zero Wayland or X11 fds open, and the SNI watcher listing LocalSend, Sunshine and Discord WITHOUT
Dropbox. It was never the bar's fault.

That default is INVERTED here, because the icon is wanted. It is enough for the daemon to inherit
the session's display for it to register `dropbox_client_<pid>` in the watcher immediately
(measured). And the bar already knows how to draw it: the `image://icon/<name>?path=<dir>` that
Dropbox publishes has its own handling in `home/desktop/quickshell/bar/Bar.qml`.

`DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-1` are NOT hardcoded: the socket name belongs to the
session, not to the host, and tomorrow it is `wayland-2`. `autostart.lua` already does
`systemctl --user import-environment WAYLAND_DISPLAY …`, so the user manager HAS both variables,
and the remedy is only to STOP zeroing `DISPLAY` and let the unit inherit it.

`mkForce` on `Environment` and not one more list item: it is a LIST, and a second `DISPLAY=…` entry
would depend on the module's merge ORDER to beat upstream's empty one, and nobody guarantees that
order. Rewriting the whole list is deterministic.

**The cost, stated explicitly**: inheriting the display requires being STARTED by the graphical
session. `After=` alone would not solve it, because what brings `graphical-session.target` up is
the compositor's `exec-once`, OUTSIDE the `default.target` transaction, so at boot the service
started earlier and fell back into headless. That is what was seen: dropbox and quickshell both at
07:11:42.

So `Install` becomes `graphical-session.target`, with `mkForce` because the module declares
`default.target` and KEEPING both would be worse than not touching it (at boot `default.target`
would bring the daemon up first, headless and iconless, and the session afterwards would not
restart an already-active unit).

The consequence is honest: **WITH NO SESSION THERE IS NO SYNC.** On this machine that is cheap
(autologin, always on), but it is a real trade, and it inherits the trap already noted in
`home/desktop/polkit-agent.nix` (home-manager#8547): if `graphical-session.target` ever goes
inactive, the sync stops with it. That is why the watcher also LOGS at warning level and does not
only notify.

## Block 1: making systemd notice the daemon dying

The home-manager module delivers `Type=forking` plus `PIDFile` plus `Restart=on-failure`, and
systemd logs on every start:

```text
Supervising process 1806 which is not our child. We'll most likely not notice when it exits.
```

That is not noise: it is systemd SAYING that its `Restart=on-failure` is decorative. The CLI's
`dropbox start` does a double fork and the PIDFile's process is not systemd's child, so the death
does not arrive as a SIGCHLD, and the service would stay `active` with the daemon already dead.

`ExitType=cgroup` changes the criterion: the unit is alive while THERE IS a process in its cgroup,
and the cgroup is something systemd really controls (the daemon does not escape it; checked in
`systemctl status`, PIDs 1797 and 1806 both inside). It requires systemd >= 250; this machine is
on 260.

`Restart=always` and not `on-failure`, and here the choice is the OPPOSITE of
`home/desktop/autostart.nix`, on purpose: there, closing an app by hand is a decision to respect;
here a stopped sync daemon is always a defect, including when what stopped it was
`dropbox-hm stop`. An explicit `systemctl --user stop dropbox` still stops it for real, since an
explicit stop never triggers Restart.

`StartLimitIntervalSec=300` plus `StartLimitBurst=5` so a real crash-loop blows the limit and the
unit DIES visibly in `systemctl --user --failed`, instead of restarting silently forever. That is
the lesson of Spotify's 4145 starts.

## Block 2: noticing the "alive but not syncing"

Block 1 covers a DEAD daemon. The failure mode that cost 10 days is another one: the daemon alive,
`active`, exit 0, a clean log, and unlinked. No process metric sees that, so the only way is to ASK
it, just like Sunshine's active probe.

The watcher is tied to `graphical-session.target` because the remedy is a notification: with no
session there is no notification daemon to receive it. The Dropbox daemon itself is NOT tied to
the session (it stays 24/7 with linger); only the warning needs somebody in front of the screen.

Four details in the script:

- `timeout 30`, because the CLI BLOCKS waiting for the daemon's socket: a hung daemon would hang
  the timer with it, and a stuck timer warns about nothing, which is exactly the failure mode the
  script exists to cover.
- `case` and NEVER `grep -q`: with `writeShellApplication`'s pipefail the grep exits on the first
  match, the producer dies of SIGPIPE, and the pipeline returns an ERROR despite the match. Same
  trap as in `home/net/mega.nix`. The matched texts come from the official CLI: "To link this
  computer to a Dropbox account, visit the following url" and "Dropbox isn't running!".
- **Anti-spam of 12 h per state**, the same idiom as `disk-watch`. Without it an unlink would
  become a notification every 30 min and the person would learn to ignore it, and an alarm that
  tires is an alarm that does not protect.
- `<4>` is systemd's level prefix (warning). Without it the line would come out at `info` and the
  unit's `LogLevelMax=warning` would SWALLOW it. It logs ALWAYS and not only when the toast fails,
  because if the graphical session is exactly what broke there is no notification daemon left.

It only NOTIFIES, it never restarts. What keeps the daemon up is block 1; two owners for the same
automation is rule 15. And in the unlink case restarting would solve nothing, because relinking
requires authorizing in the BROWSER.

**Only the timer triggers it**, and that is why the service carries NO `Install`. It used to also
be `WantedBy=graphical-session.target`, and that made the oneshot fire at session start, before the
daemon finished its handshake and before there was any notification daemon to receive the toast.
The result was a FALSE alarm in every boot, three minutes ahead of the real probe:

```text
07:11:23 dropbox-link-watch[2180]: Dropbox is down, dead
07:11:23 dropbox-link-watch[2241]: Failed to show notification: ...ServiceUnknown
07:14:21 dropbox-link-watch[12004]: Dropbox UNLINKED, nothing is syncing, unlinked
```

The `OnActiveSec` below exists to cover exactly that transient, and the `WantedBy` on the service
went over its head. An alarm that cries at every boot is the alarm that tires, which is the same
thing the 12 h anti-spam is there to prevent.

**The timer**: `OnActiveSec = 3min` so the daemon can come up and handshake with the cloud before
the first probe, otherwise the transient startup state would become a false alarm.
`OnUnitActiveSec = 30min` is plenty of resolution: an unlink does not resolve itself, and the
damage grows in days (10, in the incident), not in minutes.
