# History: october 2026

1 entry. Index in [README.md](../README.md).

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
