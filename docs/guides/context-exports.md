# Exports for the context repo: the provider steps Nix cannot reach

The [memory servers](../notes/apps/basic-memory.md) index the context repository, and my history
with each provider has to reach it first. All three providers require clicking through a web UI and
waiting for an email, which is why this is a guide and not a module. This guide stops at the file
on disk: turning an export into knowledge is the context repo's own tooling.

## The two rules that make the rest safe

1. **Raw exports never enter any git.** They are large, immutable, and an export mixes every scope,
   FAI included, in the same files, so no path inside a repository could hold one safely. They live
   in `~/context-raw/<product>/<YYYY-MM-DD>/`, outside the work tree (the context repo's ADR 0005).
2. **Nothing derived from an export reaches a committed path before it is classified by scope.**
   Classification runs on a local model and I review it (ADR 0004). That is why `bm import` is not
   used: it writes an export straight into a project, FAI conversations included.

## Fixed context

| What | Value |
| --- | --- |
| Knowledge base | the context repo, `my.memory.dir` (private `v1cferr/context`) |
| Raw exports | `~/context-raw/<product>/<YYYY-MM-DD>/`, outside git |
| Backup | none right now (rule 6); a provider can produce an export again while the account exists |

## 1. ChatGPT

**Export.** Profile menu, `Settings`, `Data controls`, `Export data`, `Export`, then confirm. The
link arrives by email, and two limits matter: it can take up to 7 days to be built, and it
**expires 24 hours** after it arrives. Download it signed into the same account that asked.

**The plan matters.** The built-in export does not exist on ChatGPT Business or Enterprise, only on
the personal plans.

**What is inside.** A zip whose useful file is `conversations.json`, next to an HTML rendering and
the account metadata. A very large history is split into numbered files.

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

Takeout can also repeat the export on a schedule (every 2 months for a year), which removes the
clicking for this provider.

## 3. Claude

**Export.** Initials in the lower left, `Settings`, `Privacy`, `Export data`. It works on the web
app and on Claude Desktop, and NOT on mobile. The link arrives by email and **expires in 24 hours**.

**Who may ask.** On Free, Pro and Max, the person themselves. On Team and Enterprise, only the
organization's **Primary Owner**, which is what makes the FAI account exportable at all: I am it.

## 4. After every download, the same two steps

```bash
# 1. the export, unchanged, in its dated directory
mkdir -p ~/context-raw/<product>/$(date +%F)
mv ~/Downloads/<the-export>.zip ~/context-raw/<product>/$(date +%F)/

# 2. the checksum of what came in, so an import can later be proven to have read exactly this
sha256sum ~/context-raw/<product>/<date>/* > ~/context-raw/<product>/<date>/SHA256SUMS
```

Then it waits for the context repo's importer, which records a committed manifest (paths, sizes
and checksums, never content) and runs the classification before anything is written to
`knowledge/`.
