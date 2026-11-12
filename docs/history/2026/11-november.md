# History: november 2026

12 entries. Index in [README.md](../README.md).

- [x] The Control Center (12/11/2026; asked 11/11/2026). How and why:
      [notes/desktop/control-center.md](../../notes/desktop/control-center.md).
      • ONE PANEL for network, Bluetooth, VPN, focus, the playing track and the sound, under its
        item on the bar's right or SUPER+A; it owns no state.
      • THE SHELL'S FIRST SLIDER AND SWITCH: `Slider`, `ControlTile`; a Sound page with the
        outputs, the inputs, the microphone and each app's level.
      • NETWORK AND BLUETOOTH PAGES on `Quickshell.Networking` and `Quickshell.Bluetooth`: wired
        links, Wi-Fi with a password field, paired devices and the ones in range; the scan and
        the discovery run only while their page is open.
      • THE VPN HAS PHASES: connecting, disconnecting and an error that says why, on top of a CLI
        that only says connected or not.
      • THE BAR GETS LEANER with it on: no volume, no bell, no network numbers.
      • A FLAG, `my.shell.controlCenter.enable`, puts the old strip back.
      • RENDERED in the headless harness against the real Pipewire; nothing was clicked or typed.

- [x] A quieter bar: the app's name, neutral colors, no bold (11/11/2026; asked 11/11/2026). How and why:
      [notes/desktop/bar.md](../../notes/desktop/bar.md), [notes/hardware/fonts.md](../../notes/hardware/fonts.md).
      • NO BOLD: Geist's 700 read as heavy on the live bar; emphasis is weight 500 over 400, picked
        from four renders, across the whole shell but the lock.
      • THE ICONS STAY on the workspaces: showing them only on a hover was tried live and undone
        the same day, at the owner's word.
      • THE APP, NOT THE WINDOW: the focused app's name replaces the window's title.
      • NEUTRAL AT REST: a steady link, a VPN that is up and a playing song are no longer green.
      • ONE OWNER EACH for the audio sink and the media player, ahead of the Control Center.

- [x] The shell in Geist, the bar's icons in Material Symbols (11/11/2026; asked 11/11/2026). How
      and why: [notes/hardware/fonts.md](../../notes/hardware/fonts.md#the-shells-own-families-11112026).
      • TWO OPTIONS, `my.fonts.shell` and `my.fonts.icons`: the shell leaves the mono UI family,
        GTK, kitty and Vicinae keep it.
      • THE 270 INLINE GLYPHS STAY: a fontconfig alias sends what Geist lacks to the Nerd Font's
        proportional cut; the plain cut drew its icons over the next letter.
      • NUMBERS STILL HOLD: tabular digits and U+2007 padding do what the mono face did.
      • OUTLINED, NOT FILLED: the FILL axis drew broken shapes on this Qt.
      • MEASURED in the headless harness: the logo still on x 1280.0 and 540.0, idle 3.8% to 4.6%
        of a core, as before. The text switches at the next rebuild.

- [x] The bar as one continuous strip of bare items (11/11/2026; asked 11/11/2026). How and why:
      [notes/desktop/bar.md](../../notes/desktop/bar.md#the-continuous-strip-11112026).
      • THE CELLS ARE GONE: an item is its glyph and label; a rounded highlight shows only on
        hover, on an open panel (the accent) or on a state that needs a look.
      • THREE REGIONS: workspaces, title and media | the logo alone on the center | alerts,
        network, VPN, sound, a bell, the tray and ONE clock on the right edge.
      • NOTHING LOST, LESS SHOWN: the weather on the clock's right click and in the NixOS Center,
        idle and away in the Center's header; CPU, disk and a stopped hypridle only when they matter.
      • Bar.qml KEEPS THE DATA: the window moved to BarStrip.qml, the sides to BarLeft and BarRight.
      • MEASURED in a headless sway, before against after: the logo on x 1280.0 and 540.0, idle
        4.1% of a core on both trees. The live session's cost is not measured yet.

- [x] ChatGPT as a tabbed web app; the desktop app left (08/11/2026; asked 08/11/2026). How and
      why: [notes/apps/chatgpt.md](../../notes/apps/chatgpt.md), [notes/apps/web-apps.md](../../notes/apps/web-apps.md).
      • THE APP WAS THE COST: Electron on OpenAI's `owl` runtime, 22 processes, about 1.6 GB RSS,
        long chats lagging, and no tabs.
      • ONE LIST: `my.webApps` holds every web app with its engine, Chrome PWA (Gemini) or a Zen
        profile with tabs (ChatGPT).
      • WHAT WENT WITH IT: pkgs/chatgpt and its overlay, the autostart hide marker, the Electron
        spellcheck seed, and the app's blocks in `~/.codex/config.toml`. Codex stays as the CLI.
      • FOUND ON THE WAY: Gemini's launcher pointed at a deleted scratch profile since 04/11.

- [x] The bar as mirrored glass cells (04/11/2026; asked 04/11/2026). How and why:
      [notes/desktop/bar.md](../../notes/desktop/bar.md).
      • A BAKE-OFF OF SIX ROUNDS on real renders (four directions, the glass family, the center,
        room for the logo, the cell states) picked it before anything touched the live shell.
      • ONE INTEGER GRID: 34 px, 24 px cells on a 1:3 slant, 4 px slits, a 12 px edge shared with
        the band and the windows; the center's left half mirrored differs from its right by 0.7/255.
      • THE LOGO GETS AIR: its compartment 3 px past the cells, 5 px around the 20 px snowflake.
      • THE RAIL SHOWS ITS APPS: icons per workspace, a click focuses that window.
      • ONE FROST for the bar and the LG's band; the dividers and the 40 px Powerline are gone.

- [x] Spellcheck in English and pt-BR in every app (03/11/2026; asked 03/11/2026). How and why:
      [notes/desktop/spellcheck.md](../../notes/desktop/spellcheck.md).
      • ONE LIST: `my.spellcheck.languages` is the SSOT, and each app family reads it its own way.
      • SYSTEM: hunspell en_US and pt_BR plus `DICPATH`, for GTK, Qt and Gecko; the dir was empty.
      • BROWSERS: Zen and LibreWolf by `spellchecker.dictionary`, Chrome by a locked policy.
      • ELECTRON: ChatGPT gets the list seeded into its Preferences on every switch (it asked
        "talv" for "tall"); Discord rewrites its own, so it stays by hand like Obsidian and Telegram.

- [x] ChatGPT desktop, the official Linux app (03/11/2026; asked 03/11/2026). How and why:
      [notes/apps/chatgpt.md](../../notes/apps/chatgpt.md).
      • OFFICIAL SINCE 11/08/2026: OpenAI ships a Linux build (preview), and nixpkgs-unstable
        packages it. Stable lists it for Darwin only, which is why the first search said no.
      • ALWAYS THE NEWEST: the channel trailed (26.1013 against OpenAI's 26.1029), so unstable's
        recipe gets OpenAI's .deb from pkgs/chatgpt, kept current by `update` like VS Code.
      • WHAT LOST: DMG ports, repack flakes, a web app and WinBoat, each for a reason in the note.
      • ONE CODEX: the app launches pkgs/codex, the same CLI the terminal uses.

- [ ] Network panel round 2: speed test, bits, a fixed axis (03/11/2026; asked 03/11/2026). How
      and why: [notes/desktop/bar.md](../../notes/desktop/bar.md#the-speed-test-03112026).
      • THE FLOATING CEILING HID THE DIRECTIONS: ↓5 Mb/s and ↑870 Mb/s drew alike. The log axis
        is now fixed from 1 kb/s to the link, with decade lines and the measured capacity dashed.
      • BITS, the plan's unit, in the pill and the panel; volumes stay in bytes.
      • `net-speedtest`: Ookla behind a lock, a button with a live gauge and a 6 h timer, one
        history. First runs: ↓927 ↑920 Mb/s, ping 7 ms, loaded 17 ms.
      • OPEN: the button and the timer after the rebuild that puts the script on the PATH.

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
      • THE PUBLIC ADDRESS, v4 and v6, from Cloudflare's trace on the probe's anchor, asked only
        when the panel opens. The nethogs wrapper verified after the rebuild: it starts with the
        panel and stops when it closes.

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
