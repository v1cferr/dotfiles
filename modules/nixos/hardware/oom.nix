# OOM: earlyoom kills the biggest process EARLY, so the machine never freezes for 30-60 s.
# Why it coexists with systemd-oomd, and the 3 traps in the regex: docs/notes/hardware/oom.md
{ ... }:

{
  services.earlyoom = {
    enable = true;
    # earlyoom's tested defaults. The swap is 100% zram (it lives in RAM), so the RAM threshold is
    # what carries the decision; if it still freezes, raise that one.
    freeMemThreshold = 10; # free RAM < 10% -> a SIGTERM to the biggest process
    freeSwapThreshold = 10; # and free swap (zram) < 10%
    enableNotifications = true; # it says on the desktop which process was killed and why

    # It matches `comm`, the KERNEL's field, truncated at 15 chars. `[.]?` and no `$` because the
    # nixpkgs wrapper renames the ELF; `[.]` and not `\.` because systemd eats the backslash.
    extraArgs = [
      # PREFER: the disposable gluttons. Editors are OUT, since unsaved work hurts more than a tab.
      "--prefer"
      "^(chrome|chromium|firefox|librewolf|zen|electron|spotify|Discord)"
      # AVOID: the compositor and shell (a frozen screen), audio, the session and SSH (no rescue).
      "--avoid"
      "^[.]?(Hyprland|quickshell|hyprlock|hypridle|hyprpaper|sshd|systemd|dbus-broker|pipewire|wireplumber)"
    ];
  };
}
