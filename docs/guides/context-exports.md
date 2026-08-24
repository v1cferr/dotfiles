# Exports into ~/context: the provider steps Nix cannot reach

The [memory server](../notes/apps/basic-memory.md) indexes `~/context`, and what it indexes has to
get there first. Two of the three providers ship an importer; the third does not. All three
require clicking through a web UI and waiting for an email, which is why this is a guide and not a
module.

## The two rules that make the rest safe

1. **Raw exports never enter the vault's git.** They are large, binary and immutable. They live in
   `~/context-raw/<provider>/<date>/`, which restic covers because it covers my whole home, and
   `.gitignore` in the vault guards the accident.
2. **An import lands in `archive/`, never in `knowledge/`.** The archive is evidence: what was
   said, when. `knowledge/` is what is true today, and it is written by hand or by an agent on
   purpose, with the archive cited as its source. Skipping that step is how a knowledge base ends
   up quoting a preference I dropped two years ago.

## Fixed context

| What | Value |
| --- | --- |
| Vault | `~/context` (private repo `v1cferr/context`, branch `main`) |
| Raw exports | `~/context-raw/<provider>/<YYYY-MM-DD>/` (outside git, inside restic) |
| Importer | `bm`, on the PATH from `pkgs/basic-memory.nix` |
| Server | `systemctl --user status basic-memory`, which must be RUNNING before any import |

## 1. ChatGPT

**Export.** Profile menu, `Settings`, `Data controls`, `Export data`, `Export`, then confirm. The
link arrives by email, and two limits matter: it can take up to 7 days to be built, and it
**expires 24 hours** after it arrives. Download it signed into the same account that asked.

**The plan matters.** The built-in export does not exist on ChatGPT Business or Enterprise, only on
the personal plans.

**What is inside.** A zip whose useful file is `conversations.json`, next to an HTML rendering and
the account metadata. A very large history is split into numbered files, and the importer takes one
file at a time.

```bash
mkdir -p ~/context-raw/chatgpt/$(date +%F) && cd ~/context-raw/chatgpt/$(date +%F)
unzip ~/Downloads/<the-export>.zip
bm import chatgpt conversations.json --folder archive/chatgpt
```

`--folder` is not optional in practice: its default is `conversations`, which would drop the whole
history at the root of the vault instead of into the archive.

## 2. Gemini (Google Takeout)

**Export.** `takeout.google.com`, signed into the account that used Gemini. Then:

1. `Deselect all`.
2. Check **Gemini**, which is the Gems data.
3. Scroll to **My Activity**, click `All activity data included`, `Deselect all`, check
   **Gemini Apps**, `Ok`. This is where the conversations actually are.
4. **Set the format to JSON.** In My Activity's `Multiple formats` button, activity records default
   to **HTML**. HTML is a rendering; JSON is data. Getting this wrong means exporting again, and the
   archive takes hours to build.
5. Delivery by email link, `.zip`, and pick a max archive size that avoids being split if possible.

**There is no importer**, so this one stops here until the converter exists. What it has to produce
is Markdown in `archive/gemini/<year>/` with the same frontmatter the other two importers write, so
that whatever indexes the vault next reads all three without knowing which provider they came from.

## 3. Claude

**Export.** Initials in the lower left, `Settings`, `Privacy`, `Export data`. It works on the web
app and on Claude Desktop, and NOT on mobile. The link arrives by email and **expires in 24 hours**.

**Who may ask.** On Free, Pro and Max, the person themselves. On Team and Enterprise, only the
organization's **Primary Owner**, which is what makes the FAI account exportable at all: I am it.

```bash
mkdir -p ~/context-raw/claude/$(date +%F) && cd ~/context-raw/claude/$(date +%F)
unzip ~/Downloads/<the-export>.zip
bm import claude conversations conversations.json --folder archive/claude
bm import claude projects projects.json --base-folder archive/claude-projects
```

Note the flag changes name between the two: `--folder` for conversations, `--base-folder` for
projects.

## 4. After every import, the same four steps

```bash
# 1. the checksum of what came in, so the archive can be proven later
sha256sum ~/context-raw/<provider>/<date>/*.json > ~/context-raw/<provider>/<date>/SHA256SUMS

# 2. the index picks the new files up on its own (BASIC_MEMORY_INDEX_CHANGES), and this says so
bm status

# 3. what actually landed, before committing thousands of files blind
cd ~/context && git status --short | head

# 4. the vault's own history
git add -A && git commit -m "chore(archive): import <provider> export of <date>"
```

Then write the note in `sources/`: what the export is, when it was requested, its checksum, and
where the raw file sits. That note is what makes a claim in `knowledge/` traceable back to a file
on disk instead of to a memory of having imported something once.

If the index and the files ever disagree, `bm reindex` rebuilds the index from the Markdown. The
Markdown is the source of truth, so that direction always works, and never the other way.
