# Site: the source previews

A page here explains a module, and the module is somewhere else. This is what puts the files a page
is about next to it on the site, in a tree, readable with highlighting without leaving the page.
The site itself is [`site.md`](site.md); this note is the half that reads the rest of the repo.

The indexer is `tools/docs-site/lib/source-index.ts`, the policy is
`tools/docs-site/source-policy.json`, the derivation is `tools/docs-site/sources.nix`. Build it with
`nix build .#docs-sources`; `pnpm --dir tools/docs-site sources` writes the same snapshot for
`pnpm dev`.

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
  written to `/_source/revision.json`, and is `null` on a dirty tree.
- **`check-sources.ts` runs in `pages`**, the first place both halves exist: nothing under
  `/_source/` the index did not publish, nothing it lists missing, every manifest well formed, every
  section id real.

The workflow prints the summary of both after the build, read back with `nix log`, so a run shows
what was indexed without `-L` dumping every build log.

## What it costs, measured on 17/10/2026

| Measure | Value |
| --- | --- |
| index time, inside `build-sources.ts` | 1.8 to 2.0s |
| `nix build .#docs-sources`, the store already fetched | 20.6s, most of it the offline install |
| pages with related files | 122 of 134 |
| relations | 651: 449 direct, 31 declared, 171 module |
| files published | 312, 1.4 MiB |
| manifests, all pages together | 156 KiB, one small file per page |
| unresolved references | 10, all of them in `docs/history/`, a diary that names deleted files on purpose |

The numbers above come from the sandbox. A dev tree reports more references "kept out by the
policy", because there the files outside the fence exist and can be classified; inside the sandbox
they do not exist at all.

**One drift it found on its first run**: `site.md` cited `tools/docs-site/lib/title.ts`, a file
renamed to `summary.ts` long ago. `docs-links` did not see it because its prose-path pattern lists
the `.nix`, `.sh` and similar extensions and not `.ts`.
