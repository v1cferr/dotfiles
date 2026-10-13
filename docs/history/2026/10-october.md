# History: october 2026

2 entries. Index in [README.md](../README.md).

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
