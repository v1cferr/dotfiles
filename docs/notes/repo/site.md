# The site

`docs/` is 88 pages and ~188k words (measured on 18/09/2026), which is a manual that had no
reader outside a file tree. This builds it into a static site at
<https://dotfiles.v1cferr.dev/>, and it changes nothing about where a file lives.

`mkdocs.yml` at the root, the hook in `scripts/mkdocs-hooks.py`, the derivation in
`pkgs/docs-site.nix`. Build it with `nix build .#docs-site`, preview it with `mkdocs serve`
inside the devShell.

## Why MkDocs, and not a framework

MkDocs is written in Python, and that is the only Python fact that matters here: it is a
generator, the same shape as Hugo or Astro. It reads `docs/*.md` and writes HTML. Nothing runs in
production, there is no backend, and the repo does not become a Python project any more than
`prettier` would make it a Node one.

**It is already in the nixpkgs this repo pins** (`mkdocs` 1.6.1, `mkdocs-material` 9.7.6 on
26.05), so the whole toolchain is `python3.withPackages` in a devShell and nothing lands in a
profile. Rule 13 stands with no extra effort: the lock pins the generator like everything else.

**Starlight and Docusaurus were passed over.** Both are good, and both are applications: they
bring a Node toolchain and a component model so that a docs site can hold interactive widgets.
There is nothing interactive here. What this needs is markdown, navigation, search, code
highlighting and a diagram now and then, which is the exact problem Material for MkDocs is built
for.

### The upstream is frozen, and that is a known cost

MkDocs 1.x has not shipped a release in 24 months, and MkDocs 2.0 is a rewrite that drops the
plugin system, moves the config to TOML and carries no license. Material's own team answered it
by building Zensical, which reads this `mkdocs.yml` as it stands.

Choosing a frozen generator is a decision and not an oversight, so the numbers, the reasoning and
the trigger to migrate are in [`../../ideas.md`](../../ideas.md). The short version is that a
generator is a build-time tool pinned in `flake.lock`, with no network exposure and nothing
running in production, and that the tree not having moved makes the switch a config change rather
than a migration.

## The nav is the ONLY topic layer, and the tree did not move

The obvious first instinct is to reorganise `docs/` to match the site: `architecture/`, `system/`,
`home/`, `hosts/`, `operations/`. That instinct was followed to its end and REJECTED, for three
reasons, in order of weight.

**A tree mirror was already measured and rejected once.** [`../README.md`](../README.md) records
it: 16 of the 51 pages of the day crossed the `system/` and `home/` boundary and 19 referenced two
or more modules, because the ARTIFACT crosses. Sections named after the repo's own directories are
that mirror wearing a different name, and `notes/` is ALREADY grouped by subject
(`boot-and-storage`, `hardware`, `network`, `desktop`, `apps`, `services`, `repo`), which is what
the reorganisation was supposed to produce.

**The tree is the durable half and the nav is the disposable one.** 193 pointers across 132 code
files resolve into `docs/`, guarded by [`link-checker.md`](link-checker.md). A nav is a
presentation layer that leaves with the generator that rendered it. Baking one into the file tree
couples the durable thing to the disposable one, which is backwards.

**Rule 17 says `git mv`, never delete and create**, because the history of a file is the product
here. 88 renames survive a `--follow`, but every one of them puts a step in it, and the whole gain
was a sidebar that `mkdocs.yml` can express for free.

So the nav is written out by hand in `mkdocs.yml`, pointing at the paths that already exist. Nine
of its twelve sections are subjects.

### What keeps the nav honest

A hand-written nav is a SECOND owner of the page list, next to the tables in
[`../README.md`](../README.md), and rule 14 says that is drift waiting to happen. It is not
theoretical: `notes/apps/spotify.md` had already fallen out of that table before this existed.

No new checker was written for it. `validation.nav.omitted_files: error` plus `--strict` makes
MkDocs itself refuse to build a site that leaves a page out of the nav, and
`validation.nav.not_found` refuses a nav entry with no file. The build IS the check, which is the
same trade rule 7 makes for shell scripts.

`validation.links.anchors` is at `warn` and not `error`, on purpose: a heading rename is a real
class of drift, but the links here are 252 between pages and only 2 carry an anchor, so promoting
it would buy almost nothing and fail the build on somebody else's heading style.

## The hook, and the 134 links the site cannot serve

A page points at the module it documents, and 134 of those targets sit OUTSIDE `docs/`
(`../../../system/services/caddy.nix`). MkDocs serves `docs_dir` and nothing else, so under
`--strict` each one is a build error.

`scripts/mkdocs-hooks.py` resolves every relative target against the page's own directory, which
is the SAME rule `docs-links` applies, and the ones that escape `docs/` become blob URLs on
GitHub. It runs at `on_page_markdown`, so the rewrite happens before MkDocs validates links, and
the markdown ON DISK is never touched: the link keeps working when the file is read on GitHub,
which is still where most of these pages get read.

Two details it has to get right. **The branch is `nixos`**, this repo's default, and `main` is a
separate orphan history, so a blob URL built from `main` is a 404 for every path here. **A fenced
code block is skipped**, or an example showing a markdown link would be rewritten into something
the example does not mean.

A link to a FOLDER (`history/`) gets that folder's index page, which is why `guides/` got a
`README.md` it never had. GitHub renders a folder listing for those and a static site has nothing
to render, so the folder either gains an index or the link dies.

## Where it runs

`pkgs/docs-site.nix` is a plain derivation running `mkdocs build --strict`. Its `src` is a
`lib.fileset` of exactly `docs/`, `mkdocs.yml` and the hook, so a commit that only touches
`system/` does not rebuild the site.

Being in `packages` means `checks.packages` builds it, so the site is part of `nix flake check`
and therefore of the CI, with no second definition of what "the site builds" means. That is the
same one-definition-three-consumers shape as the pre-commit gate in [`flake.md`](flake.md).

The sandbox has no network, which rules out the plugins that need one (`git-revision-date`,
Material's social cards). Nothing here wants them.

## The two halves Nix does not reach

Deploy is `.github/workflows/docs.yml`, on every push to `nixos`. Two settings live outside the
repo and are worth knowing about before debugging a 404:

- **Pages source has to be "GitHub Actions"** in the repository settings, not "Deploy from a
  branch". The workflow uploads an artifact and the classic branch mode ignores it.
- **The DNS record for `dotfiles.v1cferr.dev`** has to be explicit. The wildcard for this zone
  points home, so without a record of its own the name resolves to the house and Caddy answers
  for a site that is not there.

`docs/CNAME` is what tells GitHub the custom domain, and it ships inside the site because
everything under `docs_dir` that is not markdown is copied verbatim.

## Diagrams

Mermaid is NOT enabled. Material renders it with a five-line `superfences` block and no library,
but enabling a renderer for zero diagrams is a declaration nobody reads, which is rule 16. The
block goes in with the first diagram, in the same commit.
