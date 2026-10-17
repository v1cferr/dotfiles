# Site: the source previews

A page here explains a module, and the module is somewhere else. This is what puts the files a page
is about next to it on the site, in a tree, readable with highlighting without leaving the page.
The site itself is [`site.md`](site.md); this note is the half that reads the rest of the repo, and
why it is built this way is [decision 0014](../../decisions/0014-source-previews-from-a-build-snapshot.md).

The indexer is `tools/docs-site/lib/source-index.ts`, the policy is
`tools/docs-site/source-policy.json`, the derivation is `tools/docs-site/sources.nix`, and the
browser half lives in `tools/docs-site/components/source/`. Build the snapshot with
`nix build .#docs-sources`; `pnpm --dir tools/docs-site dev` writes it first for a dev tree.

## Which files a page is about, and how sure the index is

Every relation is READ, never guessed from a file name. Three strengths, and the strongest one wins
when a file is reached more than one way:

| Relation | Read from | What it means |
| --- | --- | --- |
| `direct` | a markdown link to a repo file, or inline code that is a repo path | the page cites the file |
| `declared` | the file's own header pointing at the page (rule 2) | the file says the page explains it |
| `module` | the folder a cited `<name>.nix` keeps beside it, or a folder the page names | context, not a citation |

**The markdown is read as a syntax tree**, with the same parser family Fumadocs compiles it with
(`mdast-util-from-markdown` and the GFM extension). A link inside a fenced block is not a `link`
node, so an example showing a markdown link is never read as one, which is the same reason
[`site.md`](site.md) gives for the link rewriter.

**The header pointer is rule 2 read in reverse.** Every module in `modules/` opens with its
`docs/` pointer, and `docs-links` already fails when one breaks, so the strongest declaration a file
can make about which page explains it was there before this index existed. No override file was
added next to it: a file that belongs to a page and is not cited by it gets the pointer in its
header, which is where rule 2 already asks for it.

**A bare name is resolved only inside the page's own modules.** `autostart.lua` on the Hyprland page
becomes a link because exactly one file of `modules/home/desktop/hypr/` ends in it. The same name is
never matched against the whole repo, and two matches leave it plain: `package.nix` on the flake page
is more than one file, so it stays code. The index counts those as `ambiguous`.

**A category is not a module.** `modules/home/` and `modules/home/desktop/` GROUP modules
([decision 0009](../../decisions/0009-modules-hosts-tools-layout.md)), so a page naming them is
pointing at the layout and not at code to read. Before that list existed in the policy, the
measured result was 1704 `module` relations, most of them `modules/home/` expanded onto pages that
only mention it; after it, 171. A module is still capped at 60 files, and a capped one is reported.

**A section is the heading the reference sits under**, slugged the way Fumadocs slugs it: the same
`github-slugger`, the first H1 left out exactly as `remark-doc-title.ts` leaves it out, and the
`[#id]` override honored. That is a reimplementation of somebody else's rule, so it is CHECKED:
`check-sources.ts` fails the build when a section id the index cites is not an `id` in the page's
HTML. A `module` relation carries no section, so a cited folder does not light up 46 files at once.

## What may be published: the policy

The site is public and the snapshot is part of it, so **being in git is not the test**. The policy
is one JSON file, read by `sources.nix` to fence the sandbox and by `lib/source-policy.ts` for the
rest, so the two cannot disagree (rule 11).

- **Roots**: `modules`, `hosts`, `pkgs`, `tools`, `flake`, `flake.nix` and `.github/workflows`. A
  file outside them never enters the sandbox, so it cannot be published by accident.
- **Languages**: an extension map to the shiki language. A file with no entry is not a source file
  for this purpose (a PNG, `extensions.txt`).
- **Excluded by path**: `secrets/`, the router's UCI mirror (`hosts/cudy-wr3000/uci/`, already
  redacted, but it is a map of the house network and the site does not need to amplify it), and
  whatever a dev tree builds under the site.
- **Excluded by name**: anything named like a secret, a credential, a token, an env file, a key or
  a lockfile. That keeps `modules/nixos/core/secrets.nix` out too, which only WIRES sops: the
  pattern is conservative on purpose, and the link to it still opens on GitHub.
- **Excluded by content**: a NUL byte is a binary. And a private key block, an age key, a sops value
  or a token shape FAILS the build, the same way gitleaks fails a commit: a credential in a
  publishable path is a bug to look at, not a file to skip quietly.
- **Over 256 KiB**: listed, not published; the preview offers GitHub instead. Nothing here reaches
  it today (the largest file, `Bar.qml`, is 91 KiB).
- **Only what some page shows is published**: an eligible file no page relates to stays on GitHub
  alone.

**Paths have one gate.** `normalizeRepoPath` turns every path the index stores into one canonical
spelling and rejects absolute paths, URLs, a `..` that climbs out of the repo, and any character no
file here has. Symlinks are never followed. The published files are named by a hash of their
content, so a name can never be a path: the browser fetches `/_source/files/<hash>.txt` and nothing
else, and a manifest naming anything that is not a hash is refused before a fetch.

## Where it runs: a second derivation, joined in `pages`

`docs-site`'s src is fenced to `docs/` on purpose, so a commit touching `modules/` does not rebuild
the site. The previews need `modules/`, so they did NOT go inside it: `docs-sources` is a separate
derivation, and `pages` joins it under `/_source/`, the same way it already joins the stats. A
`modules/` commit rebuilds the snapshot (about 20s) and not the site.

- **One lockfile, one fetch.** It reuses the site's `pnpmDeps`, the fixed-output store, so the
  parser costs no second hash to keep. The four packages it imports were already in the lockfile as
  dependencies of Fumadocs; making them direct moved the lockfile's importers and not the store, and
  `nix build .#docs-site.pnpmDeps --rebuild` confirmed the hash.
- **The tests run in the build.** `checkPhase` runs `node --test`, so `nix flake check` runs them,
  and a fixture test and a real-tree test (Hyprland, Vicinae, Quickshell, Caddy, a page with no
  source) both live there.
- **No git in the sandbox, and none needed.** The snapshot is the flake source itself, which is
  exactly the commit being built. The revision for GitHub links comes from `self.rev` in `pages`,
  written to `/_source/revision.json`, and is `null` on a dirty tree. It is ALSO `null` under
  `--override-input`, which the CI needs for the private input: Nix drops `rev` from `self` when an
  input is overridden, even on a clean checkout (found on the first deploy, 17/10/2026). So the
  workflow writes the commit it already knows, `github.sha`, into the staged copy, and the browser
  falls back to the branch whenever the file says `null`.
- **`check-sources.ts` runs in `pages`**, the first place both halves exist: nothing under
  `/_source/` the index did not publish, nothing it lists missing, every manifest well formed, every
  section id real.

The workflow prints the summary of both after the build, read back with `nix log`, so a run shows
what was indexed without `-L` dumping every build log.

## On the page: a tab beside the outline, and a sheet for the code

**The right column is Fumadocs' own TOC slot.** `DocsPage` takes `slots.toc.main`, a documented
extension point, and `components/source/side-panel.tsx` fills it with two tabs: the outline the
column always had (Fumadocs' own `TOCItems` and `TOCItem`, the `clerk` style unchanged) and
**Files**, the page's tree. The slot claims the column the way the default does, through the grid
area `toc` and the `layout:` variant Fumadocs defines for exactly that. Nothing patches the DOM or
reads an internal selector. The chosen tab is remembered for the next page.

**The tree is real paths, folded to what the page cites.** Folders that lead to a `direct` or
`declared` file open; a `module` file shows muted, in a folded folder, until it is asked for. A
chain of single-child folders is one row (`modules/home/desktop`). A folder opened or closed by hand
stays that way on the next page that shows it, for the whole visit. A filter narrows by name, and
the line under the tree names the path of the row the reader is on.

**Fumadocs' `<Files>` is the container, and `<Folder>` and `<File>` are not used.** In 16.17.2
`Folder` keeps its open state to itself, so a choice could not outlive a page, and `File` is a
`div` with no role, no selection and no keyboard. The rows are a WAI-ARIA tree view instead: a flat
list with `aria-level`, one tab stop that moves, arrows to walk and fold, Enter or Space to open.
The keyboard logic is a pure function in `tree.ts`, which is what lets node's test runner cover it.

**The section on screen marks its files, and moves nothing.** A file cited under the heading the
reader is on gets a dot in the tree, from the same active anchor the outline highlights with.
Nothing is reordered and nothing opens: a selection only changes when the reader changes it.

**The preview is a sheet on the right, not a dialog.** Opening a file leaves the page readable on
the left and scrolled exactly where it was, with no navigation. The sheet shows the name, the
path, the language and why the file is related, with the sections that cite it as links back into
the page. Its buttons copy the path, copy the content (the bytes, not text scraped off the DOM),
open the file on GitHub at the snapshot's own commit, and take the full width. It resizes from its
edge with the mouse or the arrow keys, and the width is remembered. Esc closes it from anywhere but
another dialog, and focus goes back to whatever opened it. The tree can show inside it too, so the
reader can walk files without going back to the column.

**A narrow screen gets a drawer and a full-width sheet.** Below `xl` the column is gone, so a
`Files` button opens the same tree in a native `<dialog>`, which brings Esc, the focus trap and the
backdrop for free, as the diagram viewer already does. The preview then takes the whole width,
and the page under it keeps its scroll.

**Two entrances move, and only with the reader's leave.** The sheet slides in and the drawer rises,
160ms each, under `prefers-reduced-motion: no-preference`. With reduced motion asked for, nothing
moves.

**The deep link is `?source=<path>&line=<n>`**, written in place with `replaceState` as files open
and close. It opens only a path the page's manifest lists, so a URL can ask for a file but never
choose one, and the line is marked and scrolled to a third of the way down.

## Links that open the preview, and stay links

`remark-repo-links.ts` still writes every href it wrote before, which a test pins. It now also
MARKS two things, and only marks them, since the site is built without the repo files:

- a link it turned into a blob URL carries `data-source-path`, plus `data-source-line` for `#L12`;
- an inline code span SHAPED like a path (a slash, or an extension) carries its text, unless it
  sits inside a link or a heading, where an anchor of its own would nest inside another.

In the browser, `a` and `code` in `components/mdx.tsx` act on a mark only when the page's manifest
says the file is real. A marked link stays the same `<a href>` to GitHub: a plain click opens the
preview, and a modified click, a middle click or "open in new tab" are the browser's, untouched.
With no JS nothing changes at all, and the link opens the file on GitHub as it always did. A code
span becomes a link ONLY when the index resolved its exact text (`autostart.lua` on the Hyprland
page); `hyprctl reload` stays code. A link the preview can open is dotted, so it reads apart from
one that leaves the page.

## The highlighter: Fumadocs' code block, on a smaller shiki

The code is drawn by Fumadocs' `DynamicCodeBlock`, so it wears the same shiki themes as a fence
(the palette's own `tokyo-night`, GitHub's light theme), the same line numbers and the same
`.highlighted` line style, with no renderer of its own. What changed is the highlighter under it.
The component's default imports shiki's whole bundle, and that wrote **330 chunk files, 12 MiB**,
into the export for grammars no page can ever ask for, measured on 17/10/2026.
`components/source/highlighter.ts` builds shiki's core with the JavaScript regex engine (no WASM)
and only the 16 grammars the policy can publish and the 5 themes the palette can name. A test fails
when either list drifts from its owner, and when a grammar does not load.

## What it costs, measured on 17/10/2026

The index, from the sandbox:

| Measure | Value |
| --- | --- |
| index time, inside `build-sources.ts` | 1.8 to 2.3s |
| `nix build .#docs-sources --rebuild`, the store already fetched | 13.1s, byte-identical to the first build |
| pages with related files | 123 of 135 |
| relations | 691: 458 direct, 41 declared, 192 module |
| files published | 323, 1.5 MiB |
| manifests, all pages together | 183 KiB, one small file per page |
| unresolved references | 10, all of them in `docs/history/`, a diary that names deleted files on purpose |

The site, against the build right before the browser half (`2e7c0caf`), on `/notes/desktop/hypr/`:

| Measure | Before | After |
| --- | --- | --- |
| JS a page loads up front, gzipped | 294.2 KiB | 302.7 KiB |
| the page's HTML, gzipped | 35.1 KiB | 35.8 KiB |
| chunk files in the export | 112, 6.3 MiB | 139, 7.5 MiB |
| the whole published output | 62.2 MiB | 66.2 MiB, `/_source/` included |

**What the first preview fetches**, in a headless Chromium: the page's manifest on load, and nothing
else until a file opens. Then 64.4 KiB gzipped of JS (the viewer, shiki's core, the engine, one
grammar, two themes) plus the file. A 250-line `.nix` was highlighted 0.5s after a deep-linked page
started loading; `Bar.qml`, the largest file at 2292 lines, took 2.0s, shown as plain text until
then. The numbers about the index come from the sandbox; a dev tree reports more references "kept
out by the policy", because there the files outside the fence exist and can be classified.

**One drift it found on its first run**: `site.md` cited `lib/title.ts`, renamed to `summary.ts`
long ago. `docs-links` did not see it because its prose-path pattern lists the `.nix`, `.sh` and
similar extensions and not `.ts`.

## How it is tested

- **In the build** (`checkPhase` of `docs-sources`, so `nix flake check`): the policy (traversal,
  exclusions, credentials), the manifest contract, the indexer on fixture repos (references,
  duplicates, direct against inferred, missing and excluded targets, symlinks, binaries, the size
  cap, determinism), the real tree (Hyprland, Vicinae, Quickshell, Caddy, a page with no source),
  the tree's keyboard and folding, what counts as a plain click, the deep link, the link rewriter's
  hrefs and marks, and the highlighter's lists.
- **At the join** (`check-sources.ts` in `pages`): the snapshot against the HTML.
- **In a real browser, by hand**: `tests/e2e/sources.e2e.ts` drives a headless Chromium over the
  DevTools protocol with node's own WebSocket, so it adds nothing to the lockfile. It covers the tree
  (folding, filter, keyboard), opening and closing with the scroll kept and focus returned, a
  modified click left to the browser, the deep link and a refused one, the section mark, a
  navigation, the empty state, reduced motion, and the drawer and full-width sheet at 390px. It is
  not in the build because a browser in the sandbox is not worth it:

```sh
nix build .#pages
CHROMIUM=$(nix build --inputs-from . nixpkgs#chromium --no-link --print-out-paths)/bin/chromium \
  SITE=$PWD/result pnpm --dir tools/docs-site test:e2e
```

It found one real bug before it passed: the path line under the tree was empty until a row had
focus, so the first press grew the drawer, which sits at the bottom, by one line, and the release
landed on another row. A finger would have done the same. The line's height is reserved now.

## What was rejected

| Option | Why not |
| --- | --- |
| building the previews inside `docs-site` | its src would have to take `modules/`, and every module commit would rebuild the site |
| the GitHub API or an embed at read time | a third party in the reader's browser, which [rule 20](../../rules.md#20-the-docs-are-a-product) forbids, plus rate limits |
| copying the repo into the export | publishes what no page shows, and what the policy exists to keep out |
| relating files by name similarity | a guess shown as a fact; the index only relates what the markdown or the file says |
| an override file for relations | rule 2's header already is one, and the gate already guards it |
| Monaco or CodeMirror | an editor for a read-only view; the site's own code block already highlights, numbers and copies |
| Fumadocs' `<Folder>` and `<File>` | uncontrolled and not keyboard-reachable in 16.17.2 (above) |
| patching the TOC in the DOM | `slots.toc` is the documented way in |
| shiki's full bundle | 330 chunk files nobody can request |

## Extending it, and when it misbehaves

- **A file is missing from a page**: cite it (a link or its repo path in backticks), or give it the
  page in its header, which is what rule 2 asks for anyway.
- **A language should be previewable**: add the extension to `source-policy.json` and the grammar to
  `components/source/highlighter.ts`; the test fails until both are there.
- **A file must never be published**: an entry in `excludePrefixes` or `excludeNames` of the policy.
  Nothing else has to change, since the fence and the indexer both read it.
- **`check-sources` names a section that does not exist**: the index slugged a heading differently
  from Fumadocs, which means Fumadocs changed its slugger or the page uses heading syntax the index
  does not read. Compare the id in the page's HTML with what `scanPage` produced for it.
- **`build-sources` refuses a file as sensitive**: look at it first. A real credential leaves the
  repo; a false match goes in `excludeNames`, and the file stays on GitHub only.
- **The Files tab says the list could not be loaded in `pnpm dev`**: the snapshot is written by
  `predev`, so a dev server started any other way has none; run `pnpm sources`.
- **Chromium dies at once in the e2e run**: an `LD_LIBRARY_PATH` exported by the host session mixes
  two glibcs; the harness drops it for the browser, so this only bites a browser started by hand.
