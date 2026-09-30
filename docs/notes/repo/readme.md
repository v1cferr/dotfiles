# The README: the header, the stats and the diagrams

The README is the one page a visitor reads without going to the [site](site.md), so it carries a
header built to look like my [profile README](https://github.com/v1cferr/v1cferr): an animated
SVG, a row of badges, and a `nix` block describing the repo the way the profile describes me.

## The stats are counted at BUILD, never committed

`pkgs/repo-stats/` runs [scc](https://github.com/boyter/scc) over the flake's own source and draws
the badges, the stats card and a `stats.json` from the result. The facts only Nix knows (the
nixpkgs release in the lock, the number of inputs, the enabled hooks, the commit's own date) enter
through `flake.nix`. `.#pages` joins that output with `docs-site` under `/stats`, and
`.github/workflows/docs.yml` publishes it, so the README points at `dotfiles.v1cferr.dev/stats/`.

Three ways were compared on 29/09/2026, and this one won on what lasts:

| Option | Why it lost or won |
| --- | --- |
| **counted at build, served by the site** | WON. A commit and its stats cannot disagree, the history gets no bot commits, and nothing is drawn by a third party |
| a workflow that commits the SVG | what the profile does, and cheap; but every change means a bot commit in the diary (rule 17) and a CI token that can write |
| shields.io reading a JSON endpoint | the familiar look, but a third party renders it, and it does not look like the profile |

**The evaluation cost stays OUT of the card.** It needs `nix eval` of a host, which a build sandbox
cannot run, so it lives where it already did: the gate's run summary, from
[`eval-metrics`](eval-metrics.md).

**The cost of the choice**: `docs.yml` used to fire only on a push touching the site, and now fires
on every push, since a commit to `system/` changes the stats. That job keeps no store cache on
purpose (a publishing job restoring a cache is zizmor's cache-poisoning finding), so each push
rebuilds the site on the runner. The machine time is the trade for numbers that are never stale.

**GitHub caches README images** through its camo proxy, so a fresh number can take a while to show
on the README even after the site has it. The source of truth is `stats/stats.json` on the site.

## The two diagrams, and why two

- **`.github/assets/flow.svg`**, hand-drawn and animated with SMIL, which GitHub renders inside an
  `<img>` (scripts are stripped, SMIL and CSS animation are not). It shows the FLOW (commit, gate,
  build, switch, and the canary closing the loop), which changes rarely, and it carries no number
  on purpose: a count drawn by hand is a count that drifts (rule 16). Its panel is dark in both
  GitHub themes, like the profile's banner, since `prefers-color-scheme` inside an SVG image is not
  reliable there.
- **The Mermaid block** inside a `<details>`, for the STRUCTURE (which directory feeds which).
  GitHub renders it natively and themes it, and it is text: it shows up in a diff and gets edited
  with the tree it describes. GitHub strips Mermaid's `click` links, so it links nowhere.

## The HTML, and markdownlint

GitHub Markdown has no syntax for a badge row or a collapsible, so the header is HTML.
`.markdownlint.jsonc` allows exactly the tags the README uses (MD033's `allowed_elements`), and
the image before the first heading is excused on its own line (MD041), so neither rule is off for
the rest of `docs/`.
