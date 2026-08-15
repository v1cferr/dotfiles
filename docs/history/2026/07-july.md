# History: july 2026

63 entries. Index in [README.md](../README.md).

9 entries landed here by INFERENCE: they have no date in the text and `git log -S` did not find the commit that introduced them (they were most likely rewritten after being created). July is the month the repo opened, so it is the conservative guess, not a fact.

- [x] Quickshell: shell/bar/OSD/media/NOTIFICATIONS in QML (ported from my Arch setup and
      adapted). It replaced waybar (removed) AND swaync (Quickshell is the
      org.freedesktop.Notifications daemon). Binary from the official flake (latest). QML
      config in home/desktop/quickshell/ through mkOutOfStoreSymlink, so HOT-RELOAD (edit a
      .qml and it reloads live; a Repeater delegate sometimes needs a qs restart,
      SUPER+ESCAPE). Arch to NixOS adaptations: GPU nvidia to sysfs xe (temperature only),
      hypridle to systemctl, monitors DP-2/HDMI-A-3, VPN dropped, Firefox to Zen.

- [x] Hyprland hot-reload + MODULAR config: hyprland.lua left the embedded text for real
      files in the repo through mkOutOfStoreSymlink (edit + `hyprctl reload`, no rebuild).
      Broken up by category (rule 5) in home/desktop/hypr/lua/*.lua: environment, monitors,
      appearance, input, autostart, rules, keybinds; hyprland.lua is only the loader (dofile
      in order). Scripts (minimize-others/brightness-osd/monitor-toggle) go to the PATH and
      Lua calls them by name. Lua API 0.55: gradient = {colors,angle}, bezier = hl.curve,
      animation = hl.animation.

- [x] Ghost monitor: the hypr-monitor-watch service (systemd --user) listens on socket2 and
      runs `hyprctl reload` on hotplug, which kills the ghost area (a cursor on the screen
      that disappeared) and moves the workspaces (TV out, so ws 5-8 go to the LG). Caveat: a
      TV that is OFF but keeps HDMI up sends no event, so that would need a manual toggle.

- [x] Brightness from the keyboard: SHIFT+VolUp/VolDown/0 = brighter/darker/reset (hyprsunset
      gamma, no real backlight). A 20% floor (clamp) plus a 150% ceiling. Native Quickshell
      OSD through IPC.

- [x] Lockscreen quotes through an API: quotes.tsv removed; a service plus timer fetches a
      batch from ZenQuotes (EN) once a day and TRANSLATES it to pt-BR through DeepL (sops key
      deepl_api_key; only the quotes in a batched request, the author left in the original)
      into a pango cache, then `shuf -n1`. Fallback: no key or DeepL down means the EN batch;
      no network means the built-in quote. Daily so it fits DeepL's free quota (500k
      chars/month).

- [x] Configure the OOM Killer: earlyoom (system/hardware/oom.nix), the companion to zram. It
      kills the BIGGEST process before the freeze from running out of RAM. --prefer
      browsers/Electron, --avoid compositor/session/sshd. It coexists with systemd-oomd (the
      backstop). Thresholds 10%/10% (the tested default); it notifies through notify-send
      (Quickshell is the daemon).

- [x] Change the wallpapers on my screenlock: the Arch ones swapped for the official NixOS
      ones through pkgs.nixos-artwork.wallpapers (declarative, no binary in git). Main =
      catppuccin-mocha (full), TV = moonscape. Blur and brightness adjusted (blur_passes 2,
      brightness 0.40). home/desktop/lockscreen.nix.
  - <https://github.com/NixOS/nixos-artwork/tree/master/wallpapers>

- [x] Add a direct zip method to my file manager's tooltip (Dolphin), zipping without opening the terminal, through the context menu (right click). DONE: kdePackages.ark ("Compress/Extract" servicemenus on right click). home/apps/dolphin.nix.

- [x] Notification software: Quickshell is the daemon (the owner of
      org.freedesktop.Notifications), with toasts plus a control center, in QML. It replaced
      swaync/mako (two daemons fight over the same D-Bus name). Standalone alternatives for
      reference: mako (minimalist) / swaync (with a control center).

- [x] Install flameshot: v14 from UNSTABLE (pkgs.unstable.flameshot, the flake overlay; the
      rest of the system stays stable) plus capture through xdg-desktop-portal, WITHOUT direct
      grim/useGrimAdapter (which removes the "grim ... GNOME" warning). TRAP: portal-hyprland
      1.3.12 DECLARES but does NOT implement the Screenshot interface ("Unknown method"), so
      xdg-desktop-portal-wlr was needed (system/desktop/desktop.nix; Screenshot=wlr routing in
      portals.conf). KEYBOARD flow (v14 forces a monitor picker on multi-monitor):
      SUPER+SHIFT+S opens the picker and enters the "screenshot" submap; 1=TV (left),
      2=main (right) SYNTHESIZE the click on the monitor preview (cursor + send_shortcut
      mouse:272; scripts in home/apps/flameshot.nix). The window has an EMPTY class and the
      title "flameshot", so the window rule matches by TITLE
      (home/desktop/hypr/lua/rules.lua).
  - <https://wiki.nixos.org/wiki/Flameshot>

- [x] Resilient remote session (29/07): what brings `hyprland-session.target` up is the
      exec-once in autostart.lua, and "autostart" comes AFTER "monitors" in the load order, so
      a Lua config that blows up means the target never comes up, which means a machine with
      no Sunshine and no Quickshell, with Hyprland alive. Remotely that is unrecoverable. Now
      a TIMER (30s) checks and brings the target up on its own, deriving
      HYPRLAND_INSTANCE_SIGNATURE and WAYLAND_DISPLAY FROM THE FILESYSTEM.
      A path unit does NOT work: `PathExistsGlob` re-triggers while the condition is true, so
      the oneshot exits, the socket is still there, it triggers again, until
      `unit-start-limit-hit` (the 1st version came up `failed` and the protection did not
      actually exist).
      And the Lua modules now load the Nix-generated data with `pcall` plus an INLINE fallback
      per file (not a global helper: Hyprland does not share globals between the `dofile`
      calls, and trying that put the compositor in emergency mode pointing at monitors.lua).
      LESSON: a systemd unit and a compositor config are NOT validated by a build, only by
      execution. `nixos-rebuild build` passes and the runtime fails.

- [x] `hyprctl -i 0` in the aliases (29/07): `rebuild`/`upgrade` ended with
      `&& hyprctl reload`, which REQUIRES HYPRLAND_INSTANCE_SIGNATURE and therefore never
      worked over SSH: rebuilding from outside left the new config on disk without applying
      it, silently. `-i 0` finds the instance from any shell.

- [x] Disk hygiene (30/07): the request was "automatic GC so the disk does not fill up", and
      the GC ALREADY existed and worked (nix.gc weekly + --delete-older-than 30d,
      auto-optimise-store with 628,191 hardlinks). Measuring before touching anything, the
      request turned out to be misaddressed:
        disk used 625.7 GiB | /nix/store 58.3 (9.3%) | NON-Nix 567.4 (90.7%)
        Bottles 319 GiB (Battlenet 181, Cities-Skylines-II 86, Ascension 47) | Jellyfin 132 |
        Games 47 | Steam 8 | Trash 1.7
      The GC's ENTIRE domain is 9% of the disk: if it fills up, it fills up through the other
      91%, and no GC policy touches a Wine prefix. So, instead of more GC:
      • min-free 1 to 15 GiB (max-free 5 to 50): collecting only when 1 GiB is left is
        arriving AFTER the accident, and the partition is shared with 506 GiB of games and
        media, so the space can disappear from outside Nix. NAMES checked with
        `nix config show`: on this Nix (2.34.8) min-free/max-free are the valid ones; the
        rename to gc-threshold/gc-limit + auto-gc belongs to a newer version and does NOT
        exist here, so following the research blindly would have produced an invalid option.
      • journald got a CEILING (SystemMaxUse=2G). There was NONE, and the systemd default is
        10% of the filesystem = ~92 GiB on this machine, with nothing to reveal it. Log growth
        is not hypothetical: two timers of MINE wrote 2148 lines/day until they got
        LogLevelMax.
      • ALARM (home/services/disk-hygiene.nix): a --user timer that notifies when free space
        drops, ALREADY WITH the biggest consumers in the message, because the request was
        being able to EVALUATE what to remove, and for that the notification has to say WHAT
        grew. Two phases on purpose: `df` (instant) every 30 min, and `du` (which takes
        MINUTES here) only when the disk is low, with nice+ionice. A 12h anti-spam per
        severity, escalating immediately if warn becomes crit, because a repetitive
        notification starts being ignored, the same mistake as a drowned journal.
      • The trash expires on its own after 30d (trash-cli, with an explicit `-f`: a unit
        waiting for an answer hangs). It was the ONLY real garbage in the measurement, 1.7 GiB
        that restic already excludes from the backup.
      • Tools: gdu (TUI) and filelight (GUI, folders) were already there. The other TWO
        questions were missing: `czkawka` (GUI, for duplicates, big files, empty folders, so
        what is DISPOSABLE, not just what is big) and `nix-tree` (which PACKAGE weighs on the
        closure; it is how we measured that xembedsniproxy costs 429 MiB of qtwebengine).
      Deliberately not automated: deleting games or media. Nobody should delete 319 GiB of
      games on their own, hence an alarm instead of a cleanup. A finding for me to decide on:
      there is a "Battle.net" bottle of 688 MiB next to the "Battlenet" one of 181 GiB, which
      looks like an abandoned attempt.

- [x] Dark mode in the file manager (Dolphin): Qt follows the dark GTK theme
      (home/desktop/theme.nix)

- [x] Keybind cheatsheet in rofi (SUPER+H, home/desktop/cheatsheet.nix): GENERATED from
      keybinds.lua at RUNTIME by an awk, never written by hand, because a duplicated list
      would become a lie on the first new bind. It reads ~/.config/hypr/lua/keybinds.lua,
      which is an mkOutOfStoreSymlink to the repo, so it even follows hot-reload with no
      rebuild. The group is the 1st line of the comment block above the bind; the description
      is the comment at the end of the line, falling back to the group text. Verified against
      `hyprctl binds`: 91/91 covered, 0 missing. TWO BUGS that cost versions: (a) finding the
      comment with a "no hyphen" regex loses legitimate descriptions (no-op, qs-restart), so
      it has to be the LAST occurrence of " -- "; (b) translating a key with a blind gsub
      swaps the "left" INSIDE "mouse_left", so it has to be token by token. H and not "/"
      because Moonlight does not send the ABNT2 "/" (the same reason as the ScrollLock remap).

- [x] [HISTORY, reverted above] The MX Master thumbwheel scrolls the tape: mouse.nix got a
      `thumbwheel` block that DIVERTS the wheel and synthesizes SUPER+CTRL+,/. (keybinds.lua
      moves ±80px).
      Why a keypress and not binding `mouse_left`/`mouse_right` (which Hyprland supports
      natively): `binds:scroll_event_delay` = 300ms is a CEILING of ~3 events/s for a wheel
      bind, which would jam the scrolling; and lowering the ceiling would ruin SUPER+vertical
      wheel for workspaces, which has hi-res scroll on. A keypress does not go through that
      ceiling.
      Why 80px and not 1 column: on the thumbwheel logiops IGNORES the `interval` after the
      1st event and sends one event per minimum increment (issue #310, OPEN), so instead of
      fighting it, the design assumes a burst, and a burst of small steps is smooth scrolling.
      Calibrate the speed in the `move ±N` of keybinds.lua (hot-reload), NEVER in the
      `interval` (a rebuild with no effect).
      Why a 3-key combo and not F13/F14 by keycode: `hl.bind("code:191", ...)` registers with
      `keycode=0` in `hyprctl binds` and there was no way to prove it fires (I cannot press
      F13); comma/period register correctly, and synthesizing a combo is already a proven
      pattern here (the gesture button has always done it). If the combo ever proves unstable
      under a burst, F13 through `code:191` is plan B (evdev 183 + 8 = xkb 191; the +8 is in
      KeybindManager.cpp:338).
      ACCEPTED COST: `divert` kills horizontal scrolling INSIDE the apps (VS Code, a wide
      table in the browser, Dolphin). If that becomes annoying, `divert = false` gives it
      back, and then the bind becomes SUPER+wheel.

- [x] Remote screen access: Tailscale (WireGuard mesh) + Sunshine/Moonlight. Sunshine
      (system/services/sunshine.nix): WLR capture (wlr-screencopy; KMS does NOT enumerate on
      the Arc's xe driver) plus encoding on the Arc GPU, access ONLY through the tailnet
      (openFirewall=false; the tailscale0 interface is trusted, so it is closed on the
      LAN/internet). Tailscale (system/net/tailscale.nix): a DECLARATIVE join through
      authKeyFile (sops/Bitwarden), so it joins the tailnet by itself on the 1st boot, with no
      manual `tailscale up`. The Sunshine web UI needs origin_web_ui_allowed=wan +
      csrf_allowed_origins (the tailnet IP/MagicDNS), otherwise "create user" fails with a
      CSRF error. Keyboard: Moonlight does NOT send the ABNT2 "/ ?" key (bug #1789), so
      ScrollLock="/" and Shift+ScrollLock="?" through hl.dsp.send_shortcut (keybinds.lua;
      wtype did not inject through the bind). Moonlight shortcuts: Capture system
      shortcuts=Always so SUPER goes through; Ctrl+Alt+Shift+Z releases and recaptures the
      mouse, +Q quits, +X goes fullscreen. The future FOSS option is Headscale.
  - [x] FIX (jul/2026) of the "?" that never came out: `send_shortcut: key not found`. The
        bind used `key = "slash"`, and send_shortcut's resolveKeycode walks the keymap with
        `xkb_state_key_get_one_sym` (LuaBindingsDispatchers.cpp), which respects the modifiers
        HELD AT THAT MOMENT, so it only finds a keysym on the ACTIVE level. In the "?" bind
        Shift is held, so level 2 is active, so no keycode produces `slash` (they produce
        `question`), so it errors. Proof: `key = "question"` WITHOUT shift fails the same way,
        mirrored. MAKING IT WORSE: m_keyToCodeCache is only populated on SUCCESS, so a
        successful "/" beforehand left the "?" working from cache, and the bug only appeared
        with a cold cache (for instance after a `hyprctl reload`), which made it look
        intermittent. FIX: `key = "code:97"`, which short-circuits BEFORE touching the xkb
        state, making it immune to modifiers and to the cache. 97 = `<AB11>`, the ABNT2 "/ ?"
        key (evdev KEY_RO 89 + 8), checked with
        `xkbcli compile-keymap --layout br --variant abnt2`. LESSON: in
        send_shortcut/send_key_state with a modifier, ALWAYS use `code:`, since a keysym is
        only reliable in a bind with no modifier.
  - [x] A long debug (jul/2026): "black screen in Moonlight" was wlr capturing the monitor in
        DPMS-OFF (not a version or encoder regression). SOLUTION: I removed dpms-off from
        hypridle (idle now ONLY locks), so the monitor is always on and it is never black.
        CAREFUL: toggling dpms UNDER an active capture caused a GPU engine reset (xe RCS) plus
        a wedged page-flip (only a reboot clears it). The global_prep_cmd guard only pauses
        hypridle during the stream (so it does not lock mid-session).
  - [x] Coming up at boot: Sunshine needs a live graphical session, so autologin (LightDM,
        defaultSession=hyprland, system/desktop/desktop.nix) plus hyprlock in the autostart
        (home/desktop/hypr/lua/autostart.lua) means it comes up LOCKED, and Moonlight lands on
        the lockscreen.
  - [x] **packet_size=1024, MANDATORY because access goes through the tailnet** (29/07).
        Symptom: Moonlight connected, paired, the host streamed without ONE error (monitor
        selected, h264_vaapi created, Opus ready, 18 MB of video going out) and the client
        disconnected in ~4 s, every time. Cause: tailscale0 has MTU 1280 and the Sunshine
        default is 1392, so every video packet blows past the tunnel, and WireGuard drops it
        SILENTLY (no ICMP, no log, no counter). The host looks perfect and the client receives
        half-frames. It had been latent forever; 1024 fits comfortably after IP+UDP+Moonlight
        headers.
  - [x] HTTPS handler healthcheck (29/07): Sunshine ended up with 47984 accepting TCP and
        NEVER completing the TLS handshake (22 connections in CLOSE-WAIT), while 47989
        answered 200. Moonlight uses HTTPS on a paired host, so it showed "offline". The
        service stayed `active`, with ExecMainStatus=0 and NOT ONE line of log: invisible by
        definition. A 2 min timer attempts the handshake and restarts after 3 failures in
        ~10 s. A TRAP that almost made it into the repo: `| grep -q` with the `set -o pipefail`
        of writeShellApplication INVERTS the result (grep exits on the 1st match, openssl dies
        of SIGPIPE, the pipeline returns an error DESPITE the match), so the 1st version read
        a successful handshake as a failure and restarted Sunshine every 2 min. Capture into a
        variable + `case`.
  - I connect through the "Low Res Desktop" app (the plain "Desktop" one latches to black on
    timing); its prep xrandr is NOT junk, it is what provides the timing slack. Same 1080p
    image.

- [x] Language: the system is en-US (output and errors in English make debugging easier), with
      an EXCEPTION, the LOCKSCREEN is fully pt-BR (the date written out, the weather, "Digite a
      senha…", quotes through DeepL). defaultLocale=en_US + supportedLocales includes pt_BR
      (the LC_TIME of the lock date depends on it). ABNT2 keyboard + BR timezone stay
      (physical and time zone, not language). Clipboard, bar and UI in en-US.
      system/core/core.nix + home/desktop/lockscreen.nix.

- [x] Review the folder architecture and the best practices for
      maintenance/organization/scalability: DONE. Reorganized by category (the community
      pattern): home/ into shell/ desktop/ apps/ services/ + packages.nix (the central list of
      user apps); system/ into core/ hardware/ net/ desktop/ services/ + packages.nix. Each
      subfolder has its default.nix. README updated.

- [x] Install software for disk usage analysis: gdu (a Go TUI, ~5x faster than ncdu on a big
      disk) plus filelight (a KDE GUI, sunburst; it integrates with Dolphin/Kvantum). Both in
      system/packages.nix. Usage: `sudo gdu -x /`.

- [x] Windows 11 theme in the file manager: Kvantum + the Win11OS-dark theme, all declarative
      (home/desktop/theme.nix). Qt stopped following GTK and became 100% Kvantum
      (platformTheme+style = kvantum; the qtstyleplugin-kvantum engine comes through the qt
      module). The theme is vendored by commit (fetchFromGitHub of
      yeyushengfan258/Win11OS-kde, only the Kvantum folder) and installed through
      qt.kvantum.themes into ~/.config/Kvantum. It only styles the INSIDE of Dolphin (the
      frame belongs to Hyprland). Windows 11 style icons: fluent-icon-theme (Fluent-dark, now
      in home/desktop/theme.nix through gtk.iconTheme.package); in Dolphin/KDE through
      kdeglobals [Icons] Theme (an activation in theme.nix), in GTK apps through dconf.

> Both with systemd (or something similar) and running as a daemon (in the background)

- [x] Add the media server (Jellyfin) with Nix: native, systemd, library in /srv/media (system/services/jellyfin.nix).

- [x] Is Bottles declarative? The APP is (home/packages.nix, with a removeWarningPopup
      override). What is INSIDE it (bottles/prefixes, games, GE-Proton runners) is STATE in
      ~/.local/share/bottles, not declarable, and it goes to the backup (rule: Nix = app+config;
      state = restic).

- [x] Is Steam declarative? YES, and it goes in system/ (programs.steam), which is the
      OFFICIAL/recommended method (the NixOS wiki + the nixpkgs manual), NOT home-manager:
      there is no programs.steam in HM. It does not break rule 4, since Steam is system
      INTEGRATION (32-bit GPU libs, the FHS wrap, controller udev, the Remote Play/LAN
      firewall), the same class as programs.hyprland, not a pure user app. What belongs to the
      user (games, login, saves) is STATE, so restic (rule 6), already excluded
      (restic.nix:38). system/gaming/steam.nix: plus Proton-GE (extraCompatPackages) plus
      gamemode. A new system/gaming/ category (rule 5).
      Game sound with OpenAL/HashLink (Northgard, Dead Cells and friends): the bundled OpenAL
      1.18.2 has no `pipewire` backend, so it goes mute; force the `pulse` backend through a
      declarative ~/.config/alsoft.conf (home/apps/openal.nix), globally for all of them.
  - <https://wiki.nixos.org/wiki/Steam>

- [x] Lockscreen and AFK/Idle mode: see "Other" (hyprlock + hypridle: lock after 5 min. The
      screen-off through dpms was REMOVED, since it broke Moonlight, see Remote access). All
      that is left is turning the LEDs off in AFK (below).

- [x] Blue light filter: hyprsunset (native to Hyprland, CTM: it does not show up in a
      screenshot or recording). A systemd --user service plus per-hour profiles in
      home/desktop/hyprsunset.nix; manual overrides on F9 (home/desktop/hypr.nix). The
      schedule is inherited from the Arch dotfiles.

- [x] Packages: home-manager vs system. THE RULE (rule 4): a USER app/config goes in home/
      (programs.* when there is a module, otherwise home.packages); system level
      (services/drivers/root) goes in system/. NEVER the same package in both. Since HM is a
      NixOS module (useGlobalPkgs+useUserPackages), 1 rebuild applies both and unfree is
      inherited. MIGRATION COMPLETE: every GUI app and CLI left system/packages.nix for the
      central home/packages.nix list plus modules with their own config
      (kitty/dolphin/flameshot/media/quickshell/theme/hypr helpers). system/ was left with
      rescue/base/diagnostics only. (git/vim stay in both on purpose: root/rescue vs
      programs.git, the single conscious exception.)

- [x] Migrate my bindings from the Arch Linux configs (Hyprland): DONE. Binds plus
      look-and-feel (gradient borders in Tokyo Night, blur, shadow, complete animations) and
      input (flat mouse accel, numlock, ABNT2) ported from Arch to modular Lua
      (home/desktop/hypr/lua/). See above.

- [x] Image Viewer: Gwenview (KDE) plus kimageformats/qtimageformats for modern formats
      (AVIF/HEIF/JXL/WebP/RAW). Themed by Kvantum, integrates with Dolphin.
      home/apps/media.nix; the image/* default through xdg.mimeApps.

- [x] PDF Viewer: Okular (KDE), PDF/EPUB/CBZ plus annotations. home/apps/media.nix; the
      application/pdf default through xdg.mimeApps.

- [x] Resolution of the 2 monitors plus adapting to a disconnect (home/desktop/hypr.nix): DP-2
      (LG ULTRAGEAR) is the main one at origin 0x0; the TV (HDMI-A-3) is to the left. Main at
      0x0 means that if the TV disconnects, the LG carries on alone with no offset (ws 5 to 8
      fall back onto it).

- [x] Google Chrome DEV channel: I swapped stable for google-chrome-dev through the
      nix-community/browser-previews flake (nixpkgs only packages stable). A new input in
      flake.nix (nixpkgs.follows for dedup) plus home/packages.nix. The binary is
      google-chrome-unstable; "latest" comes from `nix flake update browser-previews`. (The
      stable one would not open because of a ghost SingletonLock from the old nixos-seagate
      host; the fix was rm ~/.config/google-chrome/Singleton*.)

- [x] Add a direct zip method to my file manager's tooltip (Dolphin), zipping without opening the terminal, through the context menu (right click). DONE: kdePackages.ark ("Compress/Extract" servicemenus on right click). home/apps/dolphin.nix.

- [x] Add a file declaring which software starts and stays active with my machine (on/off):
      DONE, a central PANEL in `system/services/toggles.nix` (`my.services.<n>`,
      mkEnableOption + mkIf/enable-gate, the idiomatic pattern). Flipping true/false plus a
      `rebuild` turns 10 optional things on and off (jellyfin, ollama, duo, sunshine,
      qbittorrent, restic, cloudflare-ddns, dropbox, discord-rpc, cs2-backup). The essential
      ones (tailscale/mouse/desktop/keyring/earlyoom) and the VPN (on demand) stay OUT.

- [x] Autostart PANEL (30/07): `my.autostart` in home/desktop/autostart.nix, what OPENS along
      with the session, in the same idiom as toggles.nix. Discord and Spotify came in as
      --user SERVICES, not `exec-once`, because exec-once does NOT restart if the app dies,
      which was what "keep it active" was missing. `Restart=on-failure` on purpose: a crash
      comes back, closing it by hand is respected (with `always` it would be impossible to
      close).
      CORRECTION (30/07): the justification above came with "(Electron exits with 0 when
      closed)", which was FALSE for Spotify: it is CEF, and `bin/spotify` MOVES the real
      process into a scope of its own (`app-org.chromium.Chromium-<pid>.scope`, outside the
      unit's cgroup), with the process systemd is following EXITING WITH 1 even when the app
      came up fine. Result: on-failure restarted every 5s, the new launcher found the live
      instance, printed "Opening in existing browser session" and TOLD THE WINDOW TO APPEAR.
      Measured in the journal: 4145 restarts in one day. A two-layer fix: `successExit=1` on
      Spotify (exiting 1 is its normal path; the unit is a LAUNCHER, not a supervisor, and
      once it escapes the cgroup systemd was not supervising anything anyway) plus a
      StartLimit of 3/5min on ALL the panel's units. The cause of the damage was not only the
      exit code: it was that there was no limit, because with RestartSec=5 it made 2
      starts/10s, always under the default burst=5, so the factory brake NEVER engaged. What
      held the bug up was the comment: it explained the wrong choice convincingly. The header
      is an INDEX of the THREE places that start things at boot (this panel, my.services, and
      the exec-once of autostart.lua for hyprlock/qs/clipboard) instead of pretending total
      centralization, since hyprlock in the exec-once is load-bearing for remote access.
      `spotify --minimized` exists but its --help says "Only works on Windows", so to avoid
      stealing focus at login the path is a window rule (`workspace N silent`), not an app
      flag.

- [x] Print aliases migrated from Arch (30/07): screenshot/scfull/sc1/sc2 in
      home/apps/flameshot.nix (next to the tool, like eza/bat in cli.nix; zsh.nix keeps only
      the shell/system ones). TESTED on v14/Wayland before porting: only `gui` opens the
      monitor picker; `full` and `screen --number` capture directly. `--number` is a Qt index,
      not a monitor name, so it does NOT come out of my.monitors. Measured by capturing both
      screens and comparing them against the wallpapers: 0 = main, 1 = TV. RE-MEASURE if the
      monitor layout changes.

- [x] Configure my app launcher (add icons, filter by most recently used, and so on): DONE,
      rofi `drun` (Fluent-dark icons + fuzzy + history/recency) themed by the single palette
      (my.theme), UI in en-US. SUPER+Q (apps) / SUPER+R (bins). It left wofi and was
      consolidated into rofi (the same tool as the clipboard). home/desktop/launcher.nix.

- [x] Clipboard manager with image/file previews plus history: DONE with rofi (not
      quickshell): cliphist + rofi with a preview (a thumbnail plus an icon per type). See
      above.

- [x] Clicking the ws-pill to switch workspace (Bar.qml): it stayed BROKEN from the migration
      to Hyprland 0.55 until 30/07, marked here as done with the wrong command. `dispatch`
      became a shortcut for `hl.dispatch(...)`, so the old form built `hl.dispatch(workspace 3)`
      and blew up in the Lua parser. The click died SILENTLY because Quickshell's `execDetached`
      does not show stderr. The correct form is `hl.dsp.focus({ workspace = N })`, and careful,
      the obvious `hl.dsp.workspace(N)` fails with "attempt to call a table value", because
      that is a TABLE (only sub-dispatchers). A Repeater delegate does not take on hot-reload:
      it needs SUPER+ESCAPE.
      That is the THIRD item marked [x] without working (along with the wallpaper and
      screenDP1), see rule 14.

- [x] Swap the part of the status bar with the Arch logo for the NixOS logo: DONE, the Nerd
      Font glyph U+F303 (nf-linux-archlinux) became U+F313 (nf-linux-nixos) on the start button
      (Quickshell's PowerMenu). home/desktop/quickshell/bar/PowerMenu.qml.

- [x] Flameshot vs the bar: a "duplicated bar" in the screenshot (30/07). The flameshot
      overlay is a normal WINDOW, and in Hyprland a window NEVER covers the `top` layer, where
      the bar lives (`hyprctl layers` shows "Layer level 2 (top): namespace: quickshell"). The
      overlay shows a FROZEN frame that already contains the bar, and the LIVE bar draws on
      top, so two bars. There is no window rule that inverts it: it is an OPEN feature request
      (hyprwm/Hyprland#4847), and the community confirms that not even the `overlay` layer
      covers a bar on `top`. The declarative FIX: an `IpcHandler` in Bar.qml (hide/unhide) plus
      flameshot-screenshot calling it around the loop it already had. ORDER MATTERS: it hides
      AFTER the window appears, when the frame has already been captured, so the bar STAYS in
      the screenshot and only the live duplicate goes away. `visible: false` unmaps the layer,
      which also frees the 30px strip for selecting a region at the top. TRAP: the IPC function
      cannot be called `show`, because it collides with the `qs ipc show` subcommand and the
      CLI never calls it (already documented in the vpn IpcHandler).

- [x] Solve the Keyring question for every app that needs a password (like Dropbox, Spotify,
      Chrome and so on): DONE with a "Login" keyring with an EMPTY password (seahorse: change
      the old Arch password to empty; non-destructive, it preserves the secrets). ROOT CAUSE:
      with AUTOLOGIN, PAM never types a password, so pam_gnome_keyring never unlocks; and
      hyprlock to keyring is demonstrably broken on NixOS (Discourse). An empty password means
      gnome-keyring-daemon unlocks itself at startup, with no prompt in any app. It is STATE
      (rule 6), not declarable. Documented in system/desktop/desktop.nix (the Keyring section).
      Discarded along the way: greetd + a Quickshell greeter (it breaks Sunshine at boot) and a
      Quickshell lockscreen (hyprlock + autologin kept, my decision).

- [x] Connect to the FAI workstation and add it as a folder through SSHFS or some similar and
      more resilient/reliable protocol so I can add it to my file manager: DONE with **rclone
      mount** (SFTP + VFS cache), NOT sshfs (which would hang with a VPN-gated host):
      ~/FAI-workstation = the workstation's `/` root, coming up and going down with the FAI VPN
      (the vpn CLI), with a declarative bookmark in Dolphin.
      home/services/fai-workstation-mount.nix.

- [x] FAI + UFSCar VPNs 100% declarative (system/net/vpn.nix): FAI=nxBender (FOSS, 3 patches:
      ssl.wrap_socket removed on py3.12, the pppd `nomp` option, split-tunnel) plus the
      self-signed cert fingerprint; UFSCar=openconnect/GlobalProtect (`--authgroup`). Both
      split-tunnel; passwords through sops/Bitwarden. A `vpn` CLI
      (connect/disconnect/status-json/menu) plus binds SUPER+N / +SHIFT+N / +CTRL+N plus a
      clickable PILL on the bar. They coexist with Moonlight (disjoint routes).
  - [x] Automatic reconnection (jul/2026): the tunnel drops ON ITS OWN ("Modem hangup" with no
        SIGTERM) and with `Restart=no` it stayed dead until reconnected by hand (12 min one
        day, ~1 h another, taking SSH and the mount down with it). Now it is `Restart=always`
        plus `RestartSec=10` on both, with a ceiling of 6 attempts/10 min: a real drop comes
        back on the 1st, and a wrong password does not hammer the portal (SonicWall and
        GlobalProtect LOCK the account on repeated attempts). `restartIfChanged=false` so a
        rebuild does not drop a tunnel in use, since the daemon-reload already applies the new
        `Restart=` to the live process. `vpn disconnect` still works: an explicit stop does not
        trigger a restart.
  - [x] A pill that does not lie (jul/2026): `systemctl is-active` on its own LIES, because
        with the portal down nxBender enters a crash-loop and systemd reports `active` for
        ~2 min PER ATTEMPT, with zero ppp0, so the pill stayed green through the entire
        outage. `status-json` now requires an active unit AND a present tunnel interface
        (UFSCar filters `tun[0-9]`, otherwise `type tun` also matches tailscale0). The `menu`
        keeps `is-active` ON PURPOSE: there the question is "is the service running?", so it
        can offer Disconnect and stop the crash-loop.

- [x] Declarative SSH to the FAI workstation (home/shell/ssh.nix, the new `programs.ssh`
      `settings` API): `ssh workstation` (200.136.209.229) plus `fai-vm`, through the FAI VPN.
      The key was authorized once with ssh-copy-id (state).
  - [x] A session that does not drop (jul/2026): VS Code's Remote-SSH died in a transient
        routing hole. We measured ~6 min of blackhole for the .229 ONLY, with ppp0 alive and
        fai-vm (.248) answering over the SAME route/tunnel, which means it is the FAI side,
        with no fix possible from here. The config now TOLERATES instead of dropping:
        `ServerAliveInterval 15` plus `ServerAliveCountMax 20` (~5 min of slack) and
        `TCPKeepAlive no` (the kernel keepalive dropped it BEFORE that deadline). As a bonus
        the keepalive holds the idle session on the SonicWall. `ControlMaster`/`ControlPersist
        10m`: Remote-SSH opens SEVERAL connections, and multiplexed into a single TCP,
        reopening dropped to 0.08 s. The workstation MAC is `8c:86:dd:61:22:12` (enp7s0,
        wired). Wake-on-LAN is NOW BUILT (it used to be "not worth it, the machine does not
        turn off"): `wake-workstation`, in home/net/fai-workstation.nix, with two strategies,
        unicast through the tunnel plus a directed broadcast of the /25 locally, plus a RELAY
        running on fai-vm, which is on the same subnet and does a real L2 broadcast (SonicWall
        does not pass a magic packet). The magic packet is in Python, not the nixpkgs
        `wakeonlan` (Perl, which drags Perl-Critic/Perl-Tidy into the build), and it is the
        SAME code as the relay, where nothing gets installed. SO_BROADCAST is mandatory; ports
        9 and 7 because an old NIC sometimes only listens on 7. NOT TESTED end to end yet: the
        workstation does not turn off, so there has been no occasion to observe the effect.
  - TRIAGE when `ssh workstation` fails, test in this order: `ping 1.1.1.1` (internet),
    `nc -zv 200.133.233.101 4433` (the VPN portal), `nc -zv 200.136.209.236 443`
    (`fai.ufscar.br`) and `ip link show type ppp` (the tunnel). Internet OK plus the portal
    and the FAI site timing out means a FAI OUTAGE, and there is nothing to adjust here (it
    already happened on 29/07: `tracepath` reached the UFSCar backbone at 200.133.233.198 and
    died on the next hop; `www.ufscar.br` was up, all of FAI was silent).

- [x] Centralized THEME system (home/desktop/palette.nix, `my.theme.name`): presets
      tokyo-night (default) / catppuccin-mocha / gruvbox-dark, with the exact official hexes.
      Switching = 1 line plus a rebuild, which recolors Quickshell (JSON through FileView),
      Hyprland (lua through dofile) and rofi/lockscreen/flameshot (they read
      `config.my.theme.palette`). nix-colors DISCARDED (archived).

- [x] Logitech MX Master 3S mouse (system/hardware/mouse.nix, logiops): DPI 2222, SmartShift,
      hi-res scroll, and the gesture button became TAPE MANAGEMENT (it used to be workspaces;
      it changed when scrolling became global and a workspace stopped being where you park a
      window): ← / → move the window along the tape (swapcol), ↑ = see everything, ↓ = focus
      one per screen, click = launcher. Each gesture synthesizes a bind that ALREADY EXISTS in
      keybinds.lua, never an action exclusive to the mouse, otherwise the SUPER+H cheatsheet
      (which is generated from keybinds.lua) would not see it.
      MOUSE AND TAPE, the summary: dragging NEVER creates a column (it stacks, hardcoded);
      what puts one window beside another with the mouse is SUPER+right-click+drag, which
      resizes the column, since scrolling implements a real resize-drag (the left edge keeps
      the right one still by adjusting the camera; the right edge keeps the left one fixed),
      and shrinking reveals the neighbor. That had always existed in keybinds.lua and I did
      not know. BT TRAP: a boot race plus the HID++ "5 tries", so a udev rule fires a oneshot
      (sleep 5 + restart logid) that reapplies it on connect/boot/wake.

- [x] Sunshine capture=wlr (system/services/sunshine.nix): the FIX for the boot hang that
      froze Moonlight. Sunshine probed the `portalgrab` backend at startup and hung on
      hyprland-share-picker, so it never opened the ports. Forcing `wlr` skips the portal
      probe.

- [x] Fix my application launcher (show the icon, filter by most recently used, and so on): a
      DUPLICATE of the launcher above; done (rofi drun). home/desktop/launcher.nix.

- [x] "Black wallpaper" (29/07). ROOT CAUSE: hyprpaper 0.8 changed the config format, from
      flat (`wallpaper = MONITOR,path` + `preload =` + `ipc =`) to a CATEGORY
      (`wallpaper { monitor = …; path = …; }`). `preload` and `ipc` do not exist anymore, not
      even as a string in the binary (`strings hyprpaper | grep -c preload` = 0). The
      home-manager services.hyprpaper module STILL generates the old format, so the daemon
      comes up, finds the 2 outputs and logs "Monitor DP-2 has no target: no wp will be
      created": no layer surface, a black background and NO parse error to reveal it.
      Diagnosis: `hyprctl layers` only showed the quickshell layer, never hyprpaper's. FIX:
      the config is now written by xdg.configFile and the module is left with just `enable`
      (the service plus the package).
      Also: `pathOf` derives the FILE NAME by reading the package, because there is no
      standard. Most are `nix-wallpaper-<attr>.png`, the catppuccin ones are
      `nixos-wallpaper-<attr>.png` and gradient-grey is NixOS-Gradient-grey.png. Before that,
      "switching = 1 attr" was a lie and would break on a catppuccin.

- [x] Check whether the Moonlight connection is stable (monitor it and have logs): DONE
      (31/07), and the MEASUREMENT knocked down four hypotheses of mine before one was left. A
      `moonlight-stats [days]` tool (system/services/sunshine.nix) lists the sessions and
      cross-references each one with the tailscaled events in the SAME interval.
      The FINDING that guides everything: the distribution is BIMODAL, so either the session
      lasts HOURS, or it dies in 3 to 60 s. Over 7 days: 67 sessions, a median of 40 s, 39 of
      them under 120 s, and the longest at 12155 s. This is not a network "degrading
      gradually"; these are two distinct regimes.
      REFUTED, each one by the same test (if the LONG sessions suffer the event MORE, it is
      survivable and it is not the cause), and the rate has to be PER MINUTE, otherwise a 3 s
      session "never" has an event just for being short, a bias that almost closed the wrong
      case:
        • Tailscale IPv4/IPv6 path flapping: only 1/39 short sessions had ONE swap, and a
          74 min session survived 40 swaps.
        • Upload saturation: the house has 347 Mbps of upstream (measured), 0% loss on an idle
          ping, 23 ms of RTT.
        • tailscaled link change/rebind (302 and 449 over 7 days, which looked VERY much like
          the culprit): 0/39 short sessions had any, and the 4455 s session took 76 link
          changes plus 114 rebinds.
        • FAI VPN blackhole: the hypothesis was good (the client is at 200.136.193.228, at
          FAI, and the nxBender split-tunnel filters only the /0, so the FAI subnets DO ENTER
          ppp0, which would capture the route to the client endpoint). Refuted: the long ones
          have MORE ppp0 up (a median of 62% of the time) than the short ones (0%), and the
          8495 s one ran with the tunnel active 100% of the time.
      What was LEFT, and it is where the host sees nothing: during EVERY short session the
      Sunshine log is clean, with no encoder, capture or network error. It disappears with the
      client. The only correlation that held was the REQUESTED BITRATE: 79 Mbps gave a median
      life of 22 s; 23.8 Mbps gave 290 s. And the default `max_bitrate` is 0 = "obey the
      client", which is how 79 Mbps got in. Hence the 10 Mbps ceiling plus FEC 30% plus
      ping_timeout 20 s.
      A REVIEW OF THAT LAST HYPOTHESIS (31/07, measuring to answer "is 10 Mbps enough to
      play?"): it got WEAKER, and two premises fell:
        • The encoder in use is AV1 (av1_vaapi, confirmed on the LIVE instance), not h264 as
          had been written. AV1 delivers ~40 to 50% more per bit, so 10 Mbps were already
          worth ~18 to 20 of h264: the ceiling was looser than we thought, by mistake and not
          by choice.
        • "The client asked for 79 Mbps" does NOT hold for this week. Cross-referencing
          `Streaming bitrate is` with the active encoder in the journal, the 7 days ran at
          19.4 Mbps, and the SHORT ones on 31/07 (15 to 68 s) were ALSO at 19.4. In other
          words: a short drop happens at a MODERATE bitrate, so bitrate is not what prevents
          it. The 79 must be from an earlier period.
        • The sample at 10 Mbps was ONE session, which did not even complete, so that ceiling
          never had a stability record and there was no A/B to preserve. Hence 10 became
          20 Mbps.
      A CONFOUNDER that now stands out: the short ones cluster in the 08:00 window, EXACTLY
      the window in which the FAI network dropped the VPN 52 times that week (see the VPN
      item). It reinforces "the FAI network", which is still a suspicion and not a fact, for
      the same reason as before: the client side is missing.
      BITRATE PER USE (what decides is how many pixels CHANGE per frame, not how fast the
      action is): a remote desktop and Hearthstone (a fixed camera) fit in 10; Cities Skylines
      II asks for 20 to 25 because a CAMERA PAN changes every pixel of the frame, the worst
      case for interframe compression, despite the game being "calm"; FPS games 30+, and there
      the bottleneck becomes latency.
      PMTU CHECKED and discarded as a cause: `ping -M do` passes with a full 1280 B all the
      way to the client, so `packet_size=1024` is correctly sized (it was the cause on 29/07,
      it is not this one). Under a burst the path shows 1.67% loss and an RTT of 20 to 312 ms,
      which is an indication of a bad FAI network, NOT proof: it is ICMP, which firewalls
      deprioritize.
      RESEARCH: the official Sunshine docs only have "Packet loss → lower the MTU" (PR #2514),
      which is what packet_size already does; tailscale/tailscale#14208 reports exactly this
      pain (moonlight+ssh dropping, "logs only say client disconnected") and is still WITHOUT
      a root cause.
      MISSING is the half the host cannot measure, the client side: the Moonlight statistics
      overlay (Ctrl+Alt+Shift+S) during a drop, and iperf3 -u from Windows to measure what the
      video flow suffers (the ICMP above does not serve). Without that, "the FAI network"
      remains the strongest suspicion and not a fact.

- [x] VPN in the topbar (30/07): clicking the pill used to open `vpn menu`, a rofi LOOSE in
      the middle of the screen, outside the shell theme. Now it is a popover ANCHORED under
      the pill (quickshell/bar/VpnPopover.qml), in the same pattern as the other panels: one
      line per VPN with a state dot plus a button that toggles Connect/Disconnect, and
      "Disconnect all" at the bottom. CLICK and not hover (there are buttons inside; a panel
      that opens on hover closes on the first distraction, the same choice as the PowerMenu).
      It is not only cosmetic: the rofi built its labels with `systemctl is-active`, which
      LIES (vpn.nix itself documents this in fai_conn/ufscar_conn: in the nxBender crash-loop
      systemd says "active" for ~2min with no ppp0), so it offered "Disconnect" on a
      disconnected VPN. The popover reads the SAME `vpn status-json` as the pill, which checks
      the TUNNEL. The `menu` subcommand and the rofi dependency were removed from the CLI.
      AND IT DELETED ~190 LINES OF DEAD CODE: shell.qml loaded an entire VPN panel that could
      not work, for 3 independent reasons: (1) it called `$HOME/.local/bin/vpn`, an ARCH path,
      verified as nonexistent here; (2) it was UNREACHABLE, since its only trigger was
      `qs ipc call vpn toggle`, from the custom/vpn module of the removed WAYBAR; (3) it
      modeled netExtender plus NetworkManager profiles and read a `neservice` field that
      status-json no longer emits. Of the three cases of that family that day (along with
      "Electron exits with 0" and xembedsniproxy), this was the worst: with the others you
      could fail to notice, this one NEVER ran once.
  - [x] Connection failure alert (31/07): failing was SILENT. You clicked Connect, nothing
        happened, and from this side it looked like a problem with the personal machine.
        `vpn diagnose <id>` plus `vpn watch <id>` (the `vpn-watch@` unit, triggered by
        fai_up/ufscar_up): 45s after the request, if there is no tunnel, it NOTIFIES saying
        WHOSE FAULT IT IS, which is the information that changes what you do next (wait for
        FAI vs touch the network or the password).
        systemd's `OnFailure=` cannot be used: with Restart=always plus
        startLimitIntervalSec=0 these units NEVER enter `failed`, they stay in an eternal
        crash-loop. The trigger is time.
        Classification by signatures MEASURED in the journal (2 days), not invented:
        ConnectTimeout on /cgi-bin/userLogin (the portal is down) = 152 occurrences, the
        common case; "Connection reset by peer" (27); "Modem hangup"/"Peer not
        responding"/"No response to N echo-requests" (the tunnel came up and dropped). ORDER
        matters: internet from here, then the portal, then the log, otherwise a "timeout" in
        the log would become FAI's fault with the local network down.
        TESTED against the REAL failure (FAI was down): the verdict was "PORTAL DA VPN FORA DO
        AR, não é a sua máquina". And the 1st test caught a defect of mine: a STOPPED unit was
        classified as "still trying" with a log from DAYS earlier, so now there is an
        is-active gate plus a 15 min window on the evidence, otherwise the diagnosis lies.
        BUILD TRAP: a backtick inside `printf '...'` is SC2016 and the build FAILS; and the
        message comes out ILLEGIBLE because shellcheck crashes when printing a line with an
        accent ("cannot encode character '\227'"), since the sandbox has no UTF-8 locale.
  - [x] The nxBender HANG: the VPN that would not come back on its own (31/07). ROOT CAUSE
        found in a guided diagnosis. The SonicWall portal accepts the TCP, the login PASSES
        ("Logging in…" then "Starting session…") and then it stops answering. nxBender calls
        the portal WITHOUT a timeout (traceback: "connect timeout=None"), so the process
        sleeps FOREVER: the unit stays `active/running`, with ZERO log lines and no tunnel,
        and `Restart=always` NEVER acts, because it only reacts to a process that EXITS.
        MEASURED EVIDENCE: 11 min hung with the connection in ESTAB and Recv-Q/Send-Q at ZERO
        (`ss -tn state all dst 200.133.233.101`); `systemctl restart` connected in 10s (ppp0 =
        192.168.50.6, split-tunnel routes, workstation:22 open, the rclone mount OK).
        It is the SAME SHAPE as the Sunshine HTTPS handler hang: active, exit 0, invisible.
        FIX: `vpn heal` plus a vpn-heal timer (2min), which restarts only when all THREE hold:
        the unit is active (somebody asked for it), the tunnel is absent, and it has been
        active for longer than the 180s GRACE. The grace is what stops the watchdog from
        killing a connection in progress (connecting takes 10 to 30s) and becoming the problem
        itself. Tested: with a healthy VPN the heal is a no-op and the MainPID does NOT change.
        The TRIAGE that separated "my machine" from "FAI", worth repeating next time:
          `ip route get <ip>`          -> a normal route, with no ppp/tun leftovers
          ip rule + ip route table 52  -> Tailscale does NOT cover the FAI IPs
          `ping <portal>`              -> 3/3, 31ms: the host is ALIVE
          TCP per port (python)        -> 4433 OPEN; 443/80/22 REFUSED (only 4433 listens)
          UFSCar control               -> `www.ufscar.br` and acessoremoto OK = a sane internet
        MEASUREMENT TRAP: `ss -tnp` without root does NOT map the PID of another user's
        process, so the "no connections" I saw was an artifact; without `-p` the connection
        showed up.

- [x] SCROLLING layout (an infinite tape) on TRIAL in ws 2 and 6, to stop jumping between
      workspaces just to keep a few windows on screen. It is NATIVE in the nixpkgs Hyprland
      0.55.4: no plugin, no flake input (hyprscrolling has nothing to do with this story). It
      lives alongside dwindle through `hl.workspace_rule({ layout = "scrolling" })`
      (monitors.lua), since general.layout is still "dwindle", so both can be compared on the
      same day and reverted by deleting 1 word.
      No `hl.config({ scrolling = ... })` block: the 7 values I wanted (column_width 0.5 = 2
      columns of 960px at 1080p, fullscreen_on_one_column, focus_fit_method, follow_focus,
      wrap_focus, direction, explicit_column_widths) ARE ALREADY the defaults, checked with
      `hyprctl getoption`. Binds in keybinds.lua: SUPER+,/. scrolls the tape by column (it is
      the KEYBOARD shortcut, it works without a mouse), SHIFT+ reorders, ALT+ cycles the
      width, I/O stacks and unstacks in the column, G recenters and SHIFT+G expands into the
      free space.
      TWO TRAPS the wiki does not mention:
      1. `fit_into_view` is DOCUMENTED in the wiki and DOES NOT EXIST in 0.55.4 ("no such
         layoutmsg for scrolling"). The equivalent that works is `fit active`. I swept the 12
         messages the binds use one by one with `hyprctl dispatch`, and only that one was a
         ghost.
      2. EVERY layout message requires a FOCUSED window: with no focus they return "no focused
         window" and do nothing, silently. That is what made me think (wrongly) that
         `move ±col` was broken, since the test windows had come up with a `silent` rule.
      3. A BIND IS GLOBAL, A LAYOUT MESSAGE IS NOT. On a dwindle ws, Hyprland answers "Unknown
         dwindle layoutmsg: move +80" and emits ONE NOTIFICATION PER EVENT, and with the
         thumbwheel firing in a burst, the screen becomes a wall of toasts. That is why the
         tape binds go through a guard (`fita()` in keybinds.lua) that only dispatches if the
         active ws is in `scrollingWs`. Three dead ends before getting there: (a) `pcall` does
         NOT swallow it, because checkResult (LuaBindingsInternal.cpp:376) emits the
         notification and returns {ok=false} without raising a Lua error, so there is nothing
         to catch; (b) you cannot ask for the layout, because the workspace object exposes
         id/name/monitor/windows/last_window and `layout` is nil, hence the ws list being
         mirrored BY HAND from monitors.lua; (c) `d()` does not execute anything, it has to be
         `hl.dispatch(d)` ("dispatcher objects cannot be called directly", literally in
         LuaBindingsDispatcherUtils.cpp:24). It cost me two measurements thinking the guard was
         broken because of (c).
      PROMOTED TO GLOBAL (jul/2026): the trial on ws 2 and 6 was approved in use, so
      `general.layout = "scrolling"` and all 8 ws became tape. Out along with it: the `layout=`
      of the workspace_rule, the `dwindle` block of appearance.lua (no ws uses it anymore) and
      the keybinds.lua guard with its mirrored list, because with no dwindle ws the error it
      avoided does not exist, and a hand-mirrored list is debt. If ANY ws goes back to dwindle,
      the guard is MANDATORY again (it is in commit 7f74ae8). `SUPER+P` (pseudo) became a
      no-op, but it answers `ok`, because it is a window dispatcher and not a layout message,
      so it produces no toast.
      STILL OPEN: with `follow_mouse=1` the focus changes on its own while the tape moves (the
      windows slide under a still cursor) and `follow_focus` recenters, leaving the
      displacement irregular. I measured focus jumping d→b→a→Zen in one test.
      `follow_focus=false` did NOT solve it (3 events with no movement, then a jump of +1520).
      It can only be judged in real use, because firing it through `hyprctl` with a still
      cursor does not reproduce actual usage.
      4. Moving a window SIDEWAYS in the same ws is `swapcol l/r` (SUPER+SHIFT+,/.), and it
         moves the WHOLE COLUMN, stack included, wrapping around at the ends. To move just ONE
         window out of a stack: `expel` (SUPER+O) first, then swapcol. Do NOT use the generic
         `window.swap({direction})`: it is not layout-aware and it merged unrelated windows
         into one column in the test.
      5. DRAGGING (SUPER+click) NEVER creates a column, it is hardcoded. In
         CScrollingAlgorithm::newTarget, the `wasDraggingWindow() && draggingTiled()` branch
         always does `droppingColumn->add(target, ...)`, which STACKS into the destination
         column; the only choice is above or below, depending on whether the cursor is above or
         below the middle of the target window. The branch that creates a column
         (`add(idx, width)`) is the one for a NEW window, and a drag does not go through it.
         There is no knob: none of the 9 `scrolling` keys touches dragging. To put things side
         by side use SUPER+O (expel) plus SUPER+SHIFT+,/. A mouse loophole: dropping in EMPTY
         AREA falls into `if (!droppingColumn)` and creates a column, but at the END of the
         tape, not where you dropped it. (This item was READ IN THE SOURCE and not measured:
         there is no way to synthesize a drag.)
      6. EVERY way of moving a window sideways STACKS. I tested all three: the drag (read in
         the source), `window.swap({direction})` and `window.move({direction})`. The last two
         were measured: they send the window INSIDE the neighboring column, not beside it.
         Side by side only exists at the COLUMN level (swapcol/expel/colresize/fit). Scrolling
         is a 1-D layout and the mouse is 2-D; that is the underlying incompatibility.
         THE MOUSE ANSWER: (a) SUPER+right-click+drag resizes the column and shrinking reveals
         the neighbor, which already existed; (b) SUPER+middle-click = expel + fit all in one
         gesture (a Lua lambda with hl.dispatch, since a bind only accepts ONE dispatcher),
         which undoes the stacking the drag causes and shows the whole tape.

- [x] A REVIEW (jul/2026) of the thumbwheel plus width, after using it: the tape became ONE
      WINDOW PER SCREEN (`scrolling.column_width = 1.0`, the only value away from the default)
      and the thumbwheel STOPPED being diverted by logiops. Now the thumb wheel does NATIVE
      horizontal scrolling inside the apps (VS Code, a wide table), and the tape only moves
      with SUPER + wheel, through a bind on `mouse_left`/`mouse_right`. What unlocked this: the
      300ms ceiling of `binds:scroll_event_delay` was the reason for ALL the logiops
      indirection, but it is only fatal for smooth scrolling in PIXELS. Moving COLUMN by
      column, with 1 column = 1 screen, 3 events/s is plenty, and then the cost of the divert
      (killing horizontal scrolling in the apps) stopped paying for itself. New binds:
      SUPER+CTRL+./, = `colresize all 1.0`/`0.5`, which acts on the WHOLE tape (SUPER+ALT+,/.
      only acts on the active column). The lesson: the 300ms ceiling is neither good nor bad in
      the abstract, it only matters if the step is small.
      VIEW MODES (the complement of the 1.0): `fit all` on SUPER+CTRL+G squeezes the WHOLE tape
      onto the screen, adapting to the count, so 4 windows become 4x470px side by side;
      SUPER+CTRL+. goes back to one per screen. It is the "see everything at once" for when
      context matters more than focus. TRAP: `colresize all N` on its own does NOT bring the
      view along. I shrank 2 columns to 0.5 and BOTH ended up off screen, to the left; `fit
      all` resizes AND repositions. A per-app alternative (tested, it works): a window_rule
      with `scrolling_width = 0.5` makes a specific app be born with half a screen.

- [x] SSOT (rule 11): DONE. `my.monitors.{primary,secondary}` in home/desktop/monitors.nix (it
      was DP-2 in 8 files and HDMI-A-3 in 7, across Nix/Lua/QML), `my.theme.iconTheme` and
      `my.theme.cursor.{name,size}` in palette.nix, and the kitty HOLE (themeFile pinned to
      tokyo_night, so switching `my.theme.name` recolored everything EXCEPT the terminal) fixed
      by mapping preset to themeFile. Each one validated with a SENTINEL: change the value,
      check that ALL consumers changed, revert and check that the store path came back
      identical.
      Found along the way: there were TWO `screenDP1` implementations in Quickshell. The one in
      Bar.qml looked for "DP-2" (correct) and the one in Theme.qml looked for "DP-1", which
      does NOT exist on this machine, so it never matched, fell back to s[0] and the
      notifications/OSD/PowerMenu/Mpris could open ON THE TV. Unified into
      `Theme.screenPrimary`, reading the SSOT.

- [x] Clipboard (Wayland): DECLARATIVE cliphist (services.cliphist, allowImages=text+image)
      plus a picker in ROFI with a PREVIEW: a thumbnail of copied images plus an icon per file
      TYPE (zip/video/pdf/exe and so on, through Fluent-dark), a Tokyo Night theme,
      SUPER+SHIFT+V. An improved migration of cliphist-rofi-img.sh from Arch (the
      clipboard-menu script). home/desktop/clipboard.nix (it replaced the old wofi-text
      picker). Plus wl-clip-persist (hypr autostart): it keeps the copy alive after the app
      closes (the fix for the Flameshot image, since on Wayland the clipboard has an owner).

- [x] Media player: VLC (a complete GUI, it plays everything out of the box).
      home/apps/media.nix (moved out of system/, per the rule: a user app goes in home).

- [x] Emulator: RPCS3 (PS3) in home/packages.nix for Uncharted 1/2/3 (the trilogy is PS3).
      PS4/U4 only through shadPS4 (experimental). Firmware and games are state (you provide
      them). Machenike G5 Pro controller: kernel 6.18 has the xpad driver (native since 6.10)
      plus Bluetooth already on, so it is just pairing (at runtime, bluetoothctl) and using it
      in Xbox/Xinput mode. Everything declarable was done.

- [x] Lockscreen: [hyprlock](https://github.com/hyprwm/hyprlock) plus hypridle, ported from
      Arch and 100% declarative (home/desktop/lockscreen.nix). NO loose .sh scripts: the logic
      lives in the BUILD (Nix) or in systemd, and runtime is a 1-line command. Widgets: a clock
      plus the pt-BR date plus the user plus a quote (ZenQuotes through a timer, translated to
      pt-BR by DeepL into a pango cache; `shuf -n1`) plus the weather (wttr.in through a systemd
      timer; a `cat` of the cache).
      Idle: lock after 5 min (it ONLY locks; dpms-off was removed because it broke
      Moonlight/Arc, see Remote access). PAM in system/desktop/desktop.nix (without it there is
      no unlock); the pt_BR locale in system/core/core.nix. SUPER+L locks immediately.
      Notifications now come from Quickshell (the native daemon).

- [x] Video Player: VLC (GUI, the video/* default) plus mpv (light and scriptable, through
      programs.mpv). home/apps/media.nix. mpv opens manually or from the CLI; changing the
      default is 1 line.

- [x] The `upgrade` alias (home/shell/zsh.nix) = `update` plus `rebuild` in a single command
      (like apt full-upgrade). The update runs as the USER (the SSH key of the private inputs)
      && the rebuild.

- [x] Wallpaper: **hyprpaper** (Hyprland's official one, static and light) plus nixos-artwork
      images (through pkgs: no binary in git, bumped along with nixpkgs; the .gitignore blocks
      *.png on purpose). Main = catppuccin-mocha, TV = moonscape, the SAME two as the
      lockscreen, so unlocking does not change the background underneath.
      home/desktop/wallpaper.nix. There are 34 options in
      `nix eval nixpkgs#nixos-artwork.wallpapers --apply builtins.attrNames`; the
      `nineish-catppuccin-*` ones exist now and did not when this was configured.
      ATTENTION: this item stayed marked [x] for months WITHOUT WORKING (the screen was black,
      see the fix item below). Documentation claiming something works is worse than an open
      TODO: it made me doubt rendering and the GPU instead of looking at the config format.
      (Alternatives for reference: swww = transitions/rotation; mpvpaper = video.)

- [x] zoxide on `cd` (home/shell/cli.nix, `--cmd cd`): `cd <partial>` jumps to the most used
      folder; `cdi` is an fzf picker. (zoxide was already enabled; I only turned `--cmd cd` on.)
