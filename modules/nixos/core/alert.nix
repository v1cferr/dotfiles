# THE ALARM, shared by every root unit that must reach me: the journal plus a critical bubble in
# every live session. Why two channels and why runuser: docs/notes/boot-and-storage/btrfs.md#the-alarm
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    libnotify
    util-linux
    writeShellApplication
    ;

  # The machine's real users (an SSOT from users.users, rule 11): who can get the bubble.
  normalUsers = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
in
{
  options.my.alert = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "`alert <app> <icon> <title> <body>`: the journal, then a critical bubble per live session.";
    default = writeShellApplication {
      name = "alert";
      runtimeInputs = [
        coreutils
        libnotify
        util-linux
      ];
      text = ''
        app="$1"
        icon="$2"
        title="$3"
        body="$4"

        printf '%s ALERT: %s\n%s\n' "''${app^^}" "$title" "$body" >&2

        # An array, not `for u in <list>`: Nix may generate ONE name and shellcheck flags the loop.
        users=( ${lib.escapeShellArgs normalUsers} )
        for u in "''${users[@]}"; do
          uid="$(id -u "$u" 2>/dev/null)" || continue
          bus="/run/user/$uid/bus"
          [ -S "$bus" ] || continue   # no live session, so only the journal, and that is fine
          # The ABSOLUTE path: runuser can rebuild the PATH and libnotify would fall out of reach.
          runuser -u "$u" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
            ${libnotify}/bin/notify-send -a "$app" -u critical \
            -i "$icon" "$title" "$body" || true
        done
      '';
    };
  };
}
