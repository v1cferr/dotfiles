# OOM: it avoids the FREEZE caused by running out of RAM (Chrome/Electron eating everything, for
# instance).
#
# A companion to zram (hardware.nix): when RAM gets tight, zram compresses; when not even that
# holds, somebody has to die BEFORE the kernel freezes the machine.
#
# The layers: systemd-oomd (on by default in NixOS) is PSI/cgroup based and reacts slowly, and
# under Hyprland the apps do not sit in monitored cgroups, so it lets things through. earlyoom is
# %-based and KILLS THE BIGGEST PROCESS early (which prevents the 30-60s freeze). The two coexist:
# earlyoom is the fast guard, oomd the cgroup backstop.
{ ... }:

{
  services.earlyoom = {
    enable = true;
    # earlyoom's tested defaults (10%/10%): a SIGTERM when free RAM < 10% AND free swap < 10% (a
    # SIGKILL at half that: 5%/5%). Acting EARLY (10%) prevents the freeze better than waiting for
    # 5%. Since the swap is 100% zram (it lives in RAM), the swap metric is not very reliable,
    # which is why we lean on the RAM threshold. If it still freezes, raise the RAM one.
    freeMemThreshold = 10; # free RAM < 10% -> a SIGTERM to the biggest process
    freeSwapThreshold = 10; # and free swap (zram) < 10%
    enableNotifications = true; # it says on the desktop which process was killed and why

    # earlyoom matches `comm`, the KERNEL's field, truncated at 15 chars, through an extended
    # regex. THREE traps, all measured on this machine on 05/08/2026:
    #
    #   1. THE NIXPKGS WRAPPER changes the name. `wrapProgram` leaves the script with the original
    #      name and the real ELF as `.X-wrapped`; what runs is the ELF, so the comm is
    #      `.Hyprland-wrapp` and `.quickshell-wra` (cut at the 15th char), NEVER "Hyprland". Hence
    #      the `[.]?` and the end WITHOUT a `$`: it matches wrapped and raw, and it survives the
    #      day a package starts (or stops) being wrapped.
    #   2. The `$` ANCHOR plus an exact name is a false sense of protection. The old list was
    #      `^(Hyprland|waybar|…|mako)$` and it matched 5 out of 10 against the live processes: the
    #      COMPOSITOR was left out for reason 1, and `waybar`/`mako` were ghosts (they left in the
    #      migration to Quickshell). Which means the comment promised "the compositor never dies"
    #      and the effect was the opposite of what was written.
    #   3. `[.]` and NOT `\.`, because the backslash DOES NOT ARRIVE. The nixpkgs module delivers
    #      the args through `Environment=EARLYOOM_ARGS=…`, and systemd discards `\.` as an invalid
    #      escape. Written as `"^\\.?"`, earlyoom logged `regex '^.?(Hyprland|…)'`, without the
    #      backslash. It still worked (`.?` is one optional character, and over-matching in
    #      --avoid errs on the safe side), but the comment became a lie. A character class has no
    #      backslash to lose.
    #      ALWAYS CHECK what the daemon PARSED, never the .nix:
    #        journalctl -u earlyoom | grep 'avoid killing'
    extraArgs = [
      # It PREFERS to kill these (the disposable gluttons, easy to reopen). NOTE: editors
      # (code/obsidian) are OUT of here on purpose, since losing unsaved work hurts more than a
      # browser does; let Chrome/Discord die before VSCode.
      "--prefer"
      "^(chrome|chromium|firefox|librewolf|zen|electron|spotify|Discord)"
      # It NEVER kills: the compositor and the shell (a frozen screen), audio, the session and SSH
      # (no rescue). quickshell takes waybar's place, since today it is the bar, the OSD AND the
      # notification daemon.
      "--avoid"
      "^[.]?(Hyprland|quickshell|hyprlock|hypridle|hyprpaper|sshd|systemd|dbus-broker|pipewire|wireplumber)"
    ];
  };
}
