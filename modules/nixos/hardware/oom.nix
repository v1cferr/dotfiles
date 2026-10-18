# OOM: earlyoom kills the biggest process EARLY, so the machine never freezes for 30-60 s.
# Why it coexists with systemd-oomd, and the 3 traps in the regex: docs/notes/hardware/oom.md
{ ... }:

{
  services.earlyoom = {
    enable = true;
    # earlyoom's defaults. BOTH must hold, and swap is zram PLUS the 16 GiB NVMe file, so the swap
    # one decides: ~21.8 GiB swapped before a kill. Why kept, and the test: docs/notes/hardware/oom.md
    freeMemThreshold = 10; # available RAM < 10% ...
    freeSwapThreshold = 10; # ... AND free swap (zram + NVMe, 24 GiB) < 10% -> a SIGTERM
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
