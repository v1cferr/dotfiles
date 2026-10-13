# History: october 2026

6 entries. Index in [README.md](../README.md).

- [x] The homelab tail is closed: none of the services Arch had and NixOS does not comes back
      (13/10/2026). That was the last open area of the Arch parity audit, so the migration is
      DONE. Each service and what covers it now: [arch-parity-audit.md](../../arch-parity-audit.md).
      • ONE BY ONE, NOT AS A BLOCK. Twelve services were weighed with an ID each (the \*arr stack,
        open-webui, Homepage, FileBrowser, RustDesk, spendflow, `ap`), and every answer was no.
      • THE PORTS WENT BACK TO THE POOL. The caddy port map "reserved" six numbers for them; a
        reservation for a service that is not coming is a lie in the map, so it was removed.

- [x] LibreWolf is on the palette, which closes the last theming item (13/10/2026). How and why:
      [notes/apps/librewolf.md](../../notes/apps/librewolf.md).
      • NOT A THEME ADD-ON, ON PURPOSE. An unsigned one needs signature checks off for every add-on,
        a bad trade in a privacy browser, so the frame is a userChrome instead.
      • THE THEME API'S NAMES ARE DEAD IN 157. A sheet with every `--lwt-*` changed nothing; each
        part's real variable was read with InspectorUtils in a throwaway profile, never the real one.

- [x] Qt is on the palette, closing the item the Stylix entry below left open (13/10/2026). The
      layers and the measurements are in [notes/desktop/theme.md](../../notes/desktop/theme.md).
      • THE DECLARED KVANTUM HAD NEVER RUN. `platformTheme.name = "kvantum"` names a plugin that
        does not exist, and the Lua pinned `gtk3` over it anyway, so Dolphin wore Breeze Dark gray.
      • THREE LAYERS, EACH MEASURED MISSING: qt6ct hands Kvantum's palette to the app, and a KDE
        color scheme generated from the palette paints Dolphin's views, which ignore the style.
      • A FALSE TRAIL FIRST. Every variant measured the same colors because `dolphin --daemon`
        took each new window over D-Bus, with the environment it had started with.

- [x] Stylix applies the palette to every app it knows, and the theme switches to any base16
      scheme (13/10/2026). Recorded as [decision 0012](../../decisions/0012-stylix-applies-the-palette.md);
      the details are in [notes/desktop/theme.md](../../notes/desktop/theme.md).
      • THE STOCK SCHEME WAS THE TRAP. `tokyo-night-dark.yaml` has the text as `#a9b1d6`, its "red"
        is the text color and its "blue" a cyan. Fed from it, Stylix would have recolored the
        desktop wrong, which is 0001's argument measured. So Stylix is fed FROM the palette.
      • GTK WAS THE REAL GAIN. About nine GTK apps were stock Adwaita gray. One more trap there:
        GTK reads the theme from dconf, and a key removed from Nix stays in dconf.
      • KITTY WAS NOT MOVED, ON MEASUREMENT. base16 has no bright ANSI slots: Stylix painted color8
        `#292e42`, which nearly hides zsh's autosuggestions. kitty, bat, btop and Spotify keep their
        official themes, now fed from the palette where they were pinned by name.
      • THE SWITCH WAS PROVED, not assumed: a build with `base16:dracula` moved Quickshell,
        Hyprland, GTK, kitty, bat, Kvantum, Zen and fzf together, then went back.
      • ONE FINDING LEFT OPEN: Qt runs on `gtk3`, not on the Kvantum palette the docs describe.
        Flipping it drew Dolphin wrong, so it is an open item instead of a blind fix.

- [x] The `arch` branch was deleted, and `main` is the only branch left (13/10/2026). Every Arch
      area was ported, replaced or dropped with its reason written in
      [arch-parity-audit.md](../../arch-parity-audit.md); the homelab is the one left open, as its
      own item. The `archive/arch-final` tag is the same commit (`ecbaa32`), so nothing was lost:
      `git show archive/arch-final:<path>` reads any old file, and GitHub browses the tag.
      • KEPT FOR ONE DAY ON PURPOSE. The rename did not delete it because the tail was still open;
        with the old tree one branch away, every "what did Arch have here?" was a lookup.
      • THE RULESET WENT FIRST. `history` blocked the deletion, so `arch` left its `include` and
        the file was re-applied before the push. It guards `main` alone now; the tags are what a
        careless delete would cost, and no branch rule covers them.

- [x] `nixos` became `main`, and the Arch tree became `arch` (12/10/2026). The working branch
      finally has the conventional name, and nothing from either history was lost.
      • RENAME, NOT A DEFAULT SWAP. GitHub's branch rename keeps the default pointing at the same
        commits, so the contributions graph never saw a different history. Pointing the default at
        the OLD `main` for even a moment would have zeroed it, which is the august incident and the
        reason the swap was never the tool here.
      • THE OLD `main` WAS FOLDED INTO `arch` FIRST. `arch` was `main` minus 2 commits (the
        netextender NAT gateway and one VS Code setting), so a fast-forward made it complete, and
        `archive/arch-final` was tagged on the same tip (`ecbaa32`). The tag was not optional:
        `archive/pre-nix-2026-07-16` forks off at `2ccecf9` and misses the last 4 Arch commits, the
        opposite of what [arch-parity-audit.md](../../arch-parity-audit.md) used to claim.
      • THREE THINGS NAMED THE BRANCH OUTSIDE GIT, and each would have failed quietly. The
        `history` ruleset blocks the deletion the rename needed, so it was disabled for the window
        and re-applied from its file. The `github-pages` environment only deployed from `nixos`, so
        the site would have stopped publishing. And Actions do not follow a rename, so the three
        `branches: [nixos]` triggers were rewritten in the first commit pushed to `main`, which is
        also the one that proved them.
      • THE 16-AREA TAIL DID NOT BLOCK IT. The audit had it as a precondition; with the Arch tree
        one branch away it is a lookup and not a loss, so it stays a separate task.
