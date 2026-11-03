# History: november 2026

1 entry. Index in [README.md](../README.md).

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
