# ═══════════════════════════════════════════════════════════════════════════
# SHUTDOWN: how long systemd waits for a unit to stop before the SIGKILL.
#
# THE SYMPTOM: "A stop job is running…" and the shutdown taking a minute and a half.
# MEASURED on 09/08/2026, over the last 10 boots: 90.3 / 90.4 / 90.5 / 90.6 s…
# Far too round a number to be real work: that is not the system doing something, it is a TIMEOUT
# firing. And the timeout was systemd's default: 90 s.
#
# A SINGLE CULPRIT, and it is on the USER's side: VS Code. It runs in a session scope
# (`app-code-<pid>.scope`, created by GLib when launching the `.desktop`) and it does not answer
# the SIGTERM: every shutdown closes the same way, `app-code-*.scope: Stopping timed out. Killing.`
# plus a SIGKILL. Before VS Code, the same pattern showed up with Chromium; it is Electron
# behavior, not this machine's.
# EVERYTHING ELSE (docker, jellyfin, the network, the unmounts, swap) stops in under 2 s. Which
# means there was nothing to optimize, only waiting on a process that was never going to answer.
#
# WHAT THIS CHANGE DOES NOT DO: it does not start killing anything that used to die a natural
# death. The SIGKILL already happened, 90 s later. Whoever saves state on SIGTERM (pipewire,
# dropbox, rclone, all the daemons) takes under 1 s and keeps saving; whoever ignores the signal
# merely stops charging us the wait.
#
# WHY 5 s on the user side and 30 s on the system side: the two sides have different tenants, and
# a single value would serve both badly:
#   • the USER side is desktop apps. Whoever was going to save has saved; what is left is a hung
#     Electron. 5 s is generous slack for an honest SIGTERM.
#   • the SYSTEM side has `docker compose down` in the ExecStop (duo, grad-radar), and `down`
#     gives EACH container 10 s of grace before killing it. A tight ceiling here would SIGKILL
#     those stacks' Postgres in the middle of the down. It does not corrupt anything, but it comes
#     back doing WAL recovery on the next boot, and the price shows up far from the cause. 30 s
#     covers the down with room to spare and is still 3x faster than the default.
#
# This is a DEFAULT, not a ceiling: a unit with its OWN `TimeoutStopSec` ignores everything here.
# Today that means qbittorrent (30 min), jellyfin (15 s), caddy (5 s), hyprpolkitagent (5 s) and
# `user@.service` (2 min, from upstream). If the shutdown ever gets slow again, look first for
# whoever declared their own value: `systemctl show <unit> -p TimeoutStopUSec`.
#
# THE TWO SIDES HAVE DIFFERENT APIS, and the asymmetry is a real trap: `systemd.extraConfig` WAS
# REMOVED (26.05 says to use `systemd.settings.Manager`, freeform), but `systemd.user.extraConfig`
# is still the only form on the user side, since `systemd.user.settings` does NOT exist (checked in
# the `options`). And the way that fails is the worst possible: writing to the removed option, the
# `nix eval` of the generated `system.conf` passes and comes out WITHOUT the line. Nothing warns
# you. That is why the validation here is not "did it build?", it is READING the generated file:
#   nix eval --raw .#nixosConfigurations.nixos-kingston.config.environment.etc.\"systemd/system.conf\".text
#
# HOW TO CHECK the effect, with no stopwatch in hand, through the journal's two stamps:
#   journalctl -b -1 -o short-precise | grep -E "Stopping User Manager|Journal stopped"
# ═══════════════════════════════════════════════════════════════════════════
{ ... }:

{
  # The system: 30 s (and not less) because of the `docker compose down`; see the block.
  systemd.settings.Manager.DefaultTimeoutStopSec = "30s";

  # The user's session: 5 s. This is where the 90 s lived (VS Code's scope).
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=5s
  '';
}
