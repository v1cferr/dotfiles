# History: november 2026

3 entries. Index in [README.md](../README.md).

- [x] The network pill and panel, readable again (03/11/2026; asked 03/11/2026). How and why:
      [notes/desktop/bar.md](../../notes/desktop/bar.md#the-three-system-panels).
      • THE GRAPH WAS LYING BY OMISSION: linear with one shared ceiling, a single 80 MB/s burst
        drew two minutes of 12 KB/s as 0 px. Now a mirrored area on a LOG axis, same scale for
        both directions, with the window's peak and volume and a formatted hover.
      • A BAKE-OFF in an isolated Quickshell instance (old panel against burst, idle and download
        on synthetic data) checked it before it touched the live shell.
      • LATENCY BECAME A GRAPH (the probe's 60 samples), the link facts a two-column grid, and the
        apps moving traffic come from nethogs, a wheel-only capability wrapper run only while the
        panel is open.
      • THE PILL HAS TWO FACES: latency at rest, rates over 512 KB/s. 64 KB/s was too low for
        this desk, measured idling between 60 KB/s and 1 MB/s.

- [x] Restart and shut down from the lockscreen (03/11/2026; asked 02/11/2026). Two icons under
      the signature; a click asks in the field's place. How and why:
      [notes/desktop/lockscreen.md](../../notes/desktop/lockscreen.md#restart-and-shut-down-from-the-lock-03112026).
      • A BAKE-OFF CHOSE THE PLACE: the corner, under the signature, or bare icons at the foot.
        Under the signature won because its ink is measured; words became icons the same day.
      • ONE STATE MACHINE: the lock is a view of `Power.qml`, like the Center's card, never a copy.
      • NO POLKIT RULE: `reboot-multiple-sessions` is already `yes` for the active session, which
        a lock does not make inactive (`pkcheck`, 03/11/2026).
      • SEEN AT THE DESK: the icons, the question, "cancelar". The harness proved Escape and the
        ignored keys through IPC; its headless sway has no pointer.

- [x] Lockscreen v6, the QML lock, verified on the real desk (03/11/2026; opened 19/10/2026).
      How it works: [notes/desktop/lockscreen.md](../../notes/desktop/lockscreen.md).
      • DAILY USE PROVED MOST OF IT: live since about 30/10/2026, 35 locks and 35 unlocks by the
        QML lock with the real password, on Hyprland, none through the fallback.
      • SEEN AT THE DESK: the wrong password's shake and message, Caps Lock, the logo, both faces.
        The fallback: the QML lock killed 10 s into a lock, hyprlock drew its field 0.14 s later.
        Not done: a DP unplug while locked.
      • TWO FINDINGS. The logo had been missing since the Obsidian vault was reorganized (its path
        is state, fixed in `2e4561d2`). And the lock's own CPU on the real panels is 7.9% of a
        core, 4x the headless harness, while the GPU stays at its 37 W floor: still open.
      • THE ONE FALLBACK IN THE JOURNAL (30/10) was a `shutdown` while locked: the compositor died
        before the lock's unit stopped. That is the shutdown order, not the lock.
