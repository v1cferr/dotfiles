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

Two details it has to get right. **The repo and the branch are READ from `mkdocs.yml`**, out of
`repo_url` and `edit_uri`, and not written in the hook as well: that would be a second owner of
a value whose staleness breaks 134 links at once, which is rule 11. Which branch it is matters,
because `main` here is a separate orphan history and a blob URL built from it is a 404 for every
path. **A fenced code block is skipped**, or an example showing a markdown link would be
rewritten into something the example does not mean.

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

## The three halves Nix does not reach

Deploy is `.github/workflows/docs.yml`, on every push to `nixos`. Three settings live outside
the repo, all configured on 18/09/2026, and all three are worth knowing about before debugging a
404:

- **The Pages source is "GitHub Actions"**, not "Deploy from a branch". The workflow uploads an
  artifact and the classic branch mode ignores it, so the build goes green and nothing appears.
- **`dotfiles.v1cferr.dev` is a CNAME of its own** to `v1cferr.github.io`, DNS-only and not
  proxied. Explicit because the `*.v1cferr.dev` wildcard points home; DNS-only because GitHub
  issues the certificate for this name and a proxy in front of it is what breaks that.
- **The router stops swallowing the name.** This is the one nobody predicts, and it fails in the
  worst direction: the site works for the world and not for me.

### The split-DNS trap, which cost nothing to fix and everything to find

`address=/v1cferr.dev/192.168.1.10` in the router's dnsmasq matches the domain AND every
subdomain, so from inside the house the name resolved to this machine and landed on Caddy, which
has no vhost for it. Every LAN query is forced through the router, so even asking `1.1.1.1`
directly returned the local answer, and the only way to see the real record from here is DoH.

The fix is four `add_list` entries forwarding that one name to the DoH proxies, the same shape
`vpn.v1cferr.dev` already uses for the same reason, on `server` and `doh_backup_server` both.
dnsmasq resolves the LONGEST matching domain, which `cesar-ssh.v1cferr.dev` already proves in
that file. See [`../../guides/router-hardening.md`](../../guides/router-hardening.md) for how
the device is reached.

`docs/CNAME` is what claims the custom domain in the artifact, and it ships inside the site
because everything under `docs_dir` that is not markdown is copied verbatim.

## Diagrams, and the CDN that came with them

A ```` ```mermaid ```` fence renders on GitHub natively and on the site through
`pymdownx.superfences`, so one source has two renderers. The first one is the module graph in
[`flake.md`](flake.md).

**Material fetches Mermaid from `unpkg.com/mermaid@11` at page load**, which is a moving pointer
in the reader's browser, the same class of trap as the VS Code `/latest/` URL, and it was the
only third-party request this site would make. So the library is VENDORED: pinned at 11.12.0 by
hash in `pkgs/docs-site.nix`, copied into the site after the build, and loaded by the one
override in `overrides/`.

Three details make that work, and each one was the reason an easier version failed:

- **The loader has a guard.** Material's bundle reads `typeof mermaid == "undefined"` before
  reaching for the CDN, so defining the global first is enough to keep it home. A `<script>` in
  the head, emitted synchronously, cannot lose that race.
- **Only on pages that draw something.** The override tests the page's markdown for the fence,
  because 2.7 MB on all 90 pages to serve one diagram is a worse trade than the CDN was.
- **`mermaid-cli` was the obvious source and is 2.1 GiB of closure**: it drags chromium. The
  tarball straight from the npm registry is 2.7 MB and the hash is one `sha256sum` away, which
  is what rule 13 asks for.

In a local `mkdocs serve` the vendored copy does not exist, since it is placed by the
derivation, so the preview falls back to the CDN and the published site never does. Preview with
`nix build .#docs-site` when that distinction matters.
