# The site

`docs/` is 92 pages and ~200k words (measured on 23/09/2026), which is a manual that had no
reader outside a file tree. This builds it into a static site at
<https://dotfiles.v1cferr.dev/>, and it changes nothing about where a file lives.

The app in `docs-site/`, the derivation in `pkgs/docs-site.nix`. Build it with
`nix build .#docs-site`, preview it with `pnpm --dir docs-site dev` inside the devShell.

**Rule 20 is what this page argues for**, and the split between the two is the usual one here:
the rule states the contract, and everything below is the reasoning, the measurements and what
was tried and rejected on the way to it.

## It was MkDocs first, and that was the right call then

The site was born on 18/09/2026 on MkDocs with Material for MkDocs, and none of the reasoning
that chose it was wrong. It was already in the pinned nixpkgs, so the whole toolchain was a
`python3.withPackages` and nothing landed in a profile. It read `docs/*.md` and wrote HTML, with
no backend and nothing running in production. Starlight and Docusaurus were passed over because
both are applications, bringing a Node toolchain and a component model for interactive widgets
this site does not have.

**What was known on the day, and written down as a bet rather than hidden:** MkDocs 1.x had not
shipped a release in 24 months, and MkDocs 2.0 is a different project wearing the same name, with
the plugin system removed, the config moved to TOML, contributions closed and no license
declared. The trigger to migrate lived in `ideas.md`, and Zensical was the candidate.

**The bet was called differently, and this page is the record of it.** Zensical was still 0.0.x
with a release every two days, which is exactly the churn rule 13 exists to keep out of this
repo, and the one piece that would not have carried over was the hook resolving the links to
source, which its compatibility page still does not document. So the exit went the other way:
to a generator whose upstream is alive, and whose extension point for that hook is a documented
API rather than an undocumented one.

**The cost of being wrong was small BY CONSTRUCTION**, which is the half worth keeping. The tree
never moved to match the generator, so what was MkDocs-specific was one config, one hook and one
derivation against 92 markdown files. This migration touched exactly those three things.

## Why Fumadocs, and what Next.js is doing here

[Fumadocs](https://fumadocs.dev/) is a documentation framework on Next.js and React. It reads
`.md` and `.mdx`, and the three things that made it the choice are all extension points the old
setup needed and had to reach for a plugin or a hook to get:

- **The URL of a page is a function I write.** `loader({ slugs, url })` takes both, so `README.md`
  can keep meaning "the page of this folder" without renaming a single file.
- **The sidebar is a value I construct.** The page tree is a documented data structure, so the
  hand-written nav carries over as TypeScript instead of YAML.
- **The markdown pipeline is remark**, which is where the link rewriting belongs, and it operates
  on a syntax tree rather than on lines of text.

**React is not in the published site as a framework.** `output: 'export'` writes plain HTML, CSS
and JS into a directory; there is no Node process in production, and Pages serves files exactly
as it did before. Next.js occupies the same slot MkDocs did: a build-time tool, pinned in
`flake.lock`, that never runs where a reader can reach it.

**shadcn/ui was passed over, and Motion with it.** Fumadocs UI already brings the sidebar, the
table of contents, the breadcrumbs, the search dialog, the copy button and the syntax
highlighting. Adding a component library on top of that would be maintenance surface bought for
nothing, and animation on a page whose job is to be read is worse than nothing. `lucide-react`
comes in as a dependency of Fumadocs UI, which is where the icons already were.

## The tree is the durable half, and it did not move

The obvious first instinct is to reorganise `docs/` to match the site. That instinct was followed
to its end and REJECTED, for three reasons, in order of weight.

**A tree mirror was already measured and rejected once.** [`../README.md`](../README.md) records
it: 16 of the 51 pages of the day crossed the `system/` and `home/` boundary and 19 referenced two
or more modules, because the ARTIFACT crosses. Sections named after the repo's own directories are
that mirror wearing a different name, and `notes/` is ALREADY grouped by subject.

**221 pointers across 157 code files resolve into `docs/`**, guarded by
[`link-checker.md`](link-checker.md). A nav is a presentation layer that leaves with the generator
that rendered it. This migration is the proof: the nav was rewritten and not one of those
pointers moved.

**Rule 17 says `git mv`, never delete and create**, because the history of a file is the product
here. 92 renames survive a `--follow`, but every one of them puts a step in it.

So the nav is written out by hand, now in `docs-site/lib/navigation.ts`, pointing at the paths
that already exist. It is the MkDocs nav carried over unchanged, entry for entry.

### What keeps the nav honest, and where it moved to

A hand-written nav is a SECOND owner of the page list, next to the tables in
[`../README.md`](../README.md), and rule 14 says that is drift waiting to happen. It is not
theoretical: `notes/apps/spotify.md` had already fallen out of that table before the site existed,
and `notes/services/libvirt.md` lived one day written, indexed and absent from the nav.

`docs-site/lib/page-tree.ts` is what refuses to build. It walks `docs/` and the nav together and
fails on a nav entry with no file, a page no entry reaches, two entries landing on one URL, and a
page with no H1 to name it. That is the same list `validation.nav` plus `--strict` produced, with
the messages written here instead of read out of a generator's options.

**It runs at the COMMIT now, and that is a measurement and not a taste.** The old check was
`mkdocs build --strict`, 7.12s, so it sat at `pre-push` and a page is added rarely. This one reads
`docs/` and one TypeScript file on BARE NODE, with no bundler and no `node_modules`: **0.14s**,
measured. At fifty times cheaper the right unit is the commit, and the gap that let libvirt
through closes by that much more.

`pkgs/docs-site-check.nix` is the wrapper the hook runs, and it takes its `node` from the site
derivation's `passthru`, so the gate and the build cannot end up on different runtimes.

## The URLs did not change, and that is checked

A reader's bookmark is not mine to break, so the URL model is exactly the one MkDocs served:

```text
docs/README.md            ->  /
docs/rules.md             ->  /rules/
docs/guides/README.md     ->  /guides/
docs/notes/repo/site.md   ->  /notes/repo/site/
```

`docs-site/lib/urls.ts` is the ONE owner of that mapping, and four things read it: the loader that
assigns a URL to each page, the plugin that rewrites the links, the nav gate and the export check.
A slug rule cannot drift between them because there is only one of it.

Two Next.js settings make it come out that way. `trailingSlash: true` writes
`/notes/repo/site/index.html` instead of `/notes/repo/site.html`, which is what Pages serves for a
directory URL, and it is also what puts the slash back on every link. And `README.md` is NOT
renamed to `index.md`: the loader's `slugs()` treats both names as the folder's own page, so the
file GitHub renders as a directory listing is the same file the site renders as a section page.

**The URL this code passes around therefore has NO trailing slash**, which looks inconsistent with
what a reader sees and is not: Fumadocs strips the slash before matching a route against the page
tree, so a tree carrying `/notes/repo/site/` matches nothing. The symptom was narrow enough to
miss, since the sidebar has its own matcher and kept highlighting the right page: the BREADCRUMB
went silently empty. Looking at the rendered page in a browser is what found it.

**What proves it:** `docs-site/scripts/finish-export.ts` runs after every build and compares the
URLs derived from `docs/` against the directories actually written to `out/`, in both directions.
A page that stopped being published and a page published from nothing both fail the build. The
migration itself was verified by diffing the two site outputs: 92 URLs, identical, plus the
`/404/` Next.js writes for its own not-found route.

## The remark plugin, and the 140 links the site cannot serve

A page points at the module it documents, and of the 452 markdown links in `docs/`, 140 have
targets OUTSIDE `docs/` (`../../../system/services/caddy.nix`). The site serves `docs/` and
nothing else, so each one would be a dead link.

`docs-site/plugins/remark-repo-links.ts` resolves every relative target against the page's own
directory, which is the SAME rule `docs-links` applies, and the ones that escape `docs/` become
blob URLs on GitHub. The markdown ON DISK is never touched, so the link keeps working when the
file is read there, which is still where most of these pages get read.

It replaces the MkDocs hook that did this and does the same four things, with one improvement.
(The hook's own path cannot be quoted here: `docs-links` would flag a backticked path to a file
that no longer exists, which is the check working.)

| Target | Becomes |
| --- | --- |
| a page inside `docs/` | its site URL, from `lib/urls.ts` |
| a path that escapes `docs/` | `.../blob/nixos/<path>` |
| a folder with a README | that folder's page |
| a folder without one | `.../tree/nixos/<path>` |

**The repo and the branch are READ from `docs-site/site.json`**, not written in the plugin as
well: that would be a second owner of a value whose staleness breaks 140 links at once, which is
rule 11. Which branch it is matters, because `main` here is a separate orphan history and a blob
URL built from it is a 404 for every path. The canary workflow reads the same file to know which
URLs are its to check.

**A fenced code block is skipped, and now for free.** The hook tracked fence openers line by line
so an example showing a markdown link would not be rewritten into something the example does not
mean. The plugin walks `link` nodes of the syntax tree, and the text inside a fence is not one, so
the class of bug the hook had to defend against cannot occur.

## Where it runs: Nix around a Node toolchain

`pkgs/docs-site.nix` is the same shape it always was, with the interior swapped. Its `src` is a
`lib.fileset` of exactly `docs/` and `docs-site/`, so a commit that only touches `system/` does
not rebuild the site, and `checks.packages` builds it, so the site is part of `nix flake check`
with no second definition of "the site builds".

The Node half is three pieces from the pinned nixpkgs:

- **`nodejs_24` and `pnpm_10`.** The pnpm MAJOR is pinned deliberately and not taken from the
  `pnpm` alias, because the store format changes between majors and the fetcher and the build
  have to agree on one.
- **`fetchPnpmDeps`** resolves `pnpm-lock.yaml` once as a fixed-output derivation. Its `src` is
  the lockfile and the manifest ALONE, so editing a page does not invalidate the one step of this
  build that needs the network.
- **`pnpmConfigHook`** unpacks that store and runs `pnpm install --offline --frozen-lockfile`.

After that the sandbox has no network and never asks for one. `NEXT_TELEMETRY_DISABLED` turns off
the only ping Next.js would still make.

`nix build .#docs-site` is **28s** on this machine with the dependencies already fetched, and the
fetch itself is **60s** the first time and never again until the lockfile moves.

### Reproducible to the byte, and the three things that were not

`nix build --rebuild` said the derivation was NOT deterministic, which is worth chasing in a repo
that pins a dependency universe: an output that differs run to run means the CI and this machine
are publishing different bytes from the same commit. Three causes, all found by that one command:

- **Next.js mints a RANDOM build id** and stamps it into every page and into the path of the
  static chunks. `generateBuildId` now returns a sha256 of `docs/` plus the app, so it changes
  when the site changes and not when the clock does.
- **shiki loads a grammar on FIRST USE**, and `cpp` appears in exactly one fence in these docs:
  that block came out unhighlighted on some builds and correct on others, a race between parallel
  workers. The languages `docs/` actually uses are preloaded, and the list is read from the fences
  themselves so it has no second owner to go stale.
- **The loader hands back the pages in the order a parallel build compiled them**, and the search
  index numbers its documents from that order. The index sorts by URL before it is built.

Five `--rebuild` runs in a row afterwards, byte-identical.

### What this cost, stated plainly

A frontend toolchain is more moving parts than `python3.withPackages`, and pretending otherwise
would be the kind of thing rule 16 calls drift. The `pnpm-lock.yaml` is 495 packages, and the
fetched dependency store is **600 MiB**, against two Python packages before. `pnpm install
--force` fetches every platform's binaries on purpose, which is most of that.

Three things make the trade acceptable rather than merely survivable. The lockfile is pinned like
every other dependency here, so rule 13 holds unchanged. None of it runs in production or in a
reader's browser: it is a build-time tool in a sandbox with no network. And `docs/` is still 92
markdown files that any generator in this class consumes, so the next exit is the same size as
this one was.

## The published site fetches NOTHING from a third party

Rule 13 does not stop at my build, it reaches the reader's browser, and a dependency somebody else
can move is not less dangerous for running in a visitor's browser than in my sandbox. It is MORE,
because I would never see it fail.

`finish-export.ts` is what enforces it now, instead of an audit somebody remembers to run. It
walks every `.html` and `.css` in the output and fails the build on any `script`, `link`, `img`,
`source`, `iframe`, `video` or `audio` pointing at an absolute URL, and on any `url()` or
`@import` in CSS doing the same. A `<a href="https://...">` in the prose is content and passes.
That closes the hole the old manual audit had: it looked at `src=` and never saw a font, because a
font arrives through `href=`.

**Mermaid ships in the bundle.** A ```` ```mermaid ```` fence renders on GitHub natively and on the
site through `remarkMdxMermaid`, which turns the fence into a component, so one source still has
two renderers. The library is a pnpm dependency pinned in the lockfile and imported dynamically,
so it is downloaded only by a reader who opens a page that draws something. That replaces the
vendored tarball and the MkDocs template that loaded it, and for the same reason: Material fetched
`unpkg.com/mermaid@11`, a moving pointer in somebody else's browser.

**No webfont, for the same reason.** Material linked Roboto from `fonts.gstatic.com` on every
page; Fumadocs UI ships no default font at all, so there is nothing to turn off. The stack in
`docs-site/app/global.css` is `system-ui` for prose and JetBrains Mono for code, neither of them
REQUIRED: both sit in front of a fallback chain, so a machine without them loses nothing. That is
what `docs/assets/stylesheets/fonts.css` used to say, and it left with MkDocs.

## The search runs in the reader's browser

The index is built into the static output as one JSON file, and the browser downloads it the first
time somebody opens the dialog. No endpoint, no backend, no third party, which is the only kind of
search Pages can host and the only kind that does not tell somebody else what I look up in my own
notes.

**It is 8.2 MB raw and 2.1 MB over the wire**, measured on 23/09/2026, which is the honest cost of
full-text search over 200k words and worth knowing before it surprises somebody on a phone. Three
things make it acceptable: it is fetched LAZILY, only when the dialog is opened and not on page
load; Pages serves it compressed; and it is cached afterwards.

Algolia and Orama Cloud would each make it a few kilobytes. Both were passed over without much
deliberation: they move the index and the queries onto somebody else's server, which is the exact
trade the mermaid CDN lost, and a search box that phones home is worse than a slow one.

## The three halves Nix does not reach

Deploy is `.github/workflows/docs.yml`, on every push to `nixos`: it builds this derivation and
hands the result to Pages, which is unchanged by the migration. Three settings live outside the
repo, all configured on 18/09/2026, and all three are worth knowing about before debugging a 404:

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

`docs/CNAME` is what claims the custom domain, and it is still the ONE owner of it: the build
copies it into the output, and the app reads it from there for the canonical URL rather than
writing the domain down a second time.

## What checks the links this generates

The same split [`link-checker.md`](link-checker.md) already draws, extended to the links that
exist only after a build:

- **In the gate, offline.** `docs-links` requires a target that leaves `docs/` to be
  git-TRACKED, not merely present, because those two stopped being the same question the day
  such a link started being published as a blob URL. It reads the site's own TypeScript too,
  since the headers there carry the same pointers every other module's do.
- **In the canary, weekly.** `lychee` over the BUILT site, filtered to this repo's own URLs,
  which it reads out of `docs-site/site.json` rather than repeating. The markdown run cannot see
  one of these links, since none of them appears in any `.md`.

`oxlint` is the JS half of the gate, over `docs-site/`. Its binary comes from nixpkgs like every
other linter here, so the lock pins it (rule 13) and nothing enters `package.json` for it; the
rules live in `docs-site/.oxlintrc.json`, which is the file the editor reads too.

## No frontmatter, and the title is the H1

Fumadocs wants a `title` for every page, and the obvious answer is a `---` block at the top of all
92 files. That was REJECTED: a `title:` next to an `# H1` is two owners of one string (rule 14),
and the drift it invites is a page whose tab says one thing and whose heading says another.

`docs-site/lib/title.ts` reads the first H1 instead, and the collection's schema is handed the raw
source before the markdown is compiled, which is where that can happen. A page with no H1 fails
the build rather than getting a made-up name. The H1 is then taken OUT of the rendered body, since
the layout renders the title itself, and `docs/` gains not one byte.

## What is still worth doing

- The generator is REPLACEABLE, and keeping it that way is the point. If Fumadocs ever goes the
  way MkDocs did, what has to be rewritten is `docs-site/`, against 92 markdown files that did not
  move. Nothing in `docs/` knows which generator renders it.
- The 2.1 MB search index is the one number I would like to see smaller without giving the index
  to somebody else. Nothing is planned, and measuring it again after the docs grow is the trigger.
