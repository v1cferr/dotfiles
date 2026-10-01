# SHUTDOWN: how long systemd waits for a unit to stop before the SIGKILL.
# Where the 90s came from and why the two sides differ: docs/notes/boot-and-storage/shutdown.md
{ ... }:

{
  # 30 s and not less: `docker compose down` gives each container 10 s of grace.
  systemd.settings.Manager.DefaultTimeoutStopSec = "30s";

  # The user's session: 5 s. This is where the 90 s lived (VS Code's scope).
  systemd.user.extraConfig = ''
    DefaultTimeoutStopSec=5s
  '';
}
