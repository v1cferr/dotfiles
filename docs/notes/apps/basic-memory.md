# basic-memory

Modules: [`pkgs/basic-memory.nix`](../../../pkgs/basic-memory.nix),
[`home/services/basic-memory.nix`](../../../home/services/basic-memory.nix)

Two memory servers over my context repository, split at the FAI boundary, instead of one archive
per agent CLI. Each is an MCP server over plain Markdown, so what it indexes is a directory I own and
the index is derived.

## The shape, and what is the product

The Markdown in the context repository (`my.memory.dir`, the private `v1cferr/context`) is the
product. Basic Memory is the INDEX over it: SQLite, a knowledge graph and MCP tools. That order is
deliberate, because it is what keeps this from being a second lock-in: the day the index stops being
worth it, the directory is still there, still readable, and still openable as an Obsidian vault.

```text
context/knowledge/ (Markdown, mine)
   |
   +-- Obsidian                 the human interface
   +-- basic-memory-general     personal, study, projects
   |      +-- codex
   |      +-- agy
   +-- basic-memory-fai         fai (private/ excluded)
          +-- Claude Code, FAI account only
```

The repository owns the content and the contract (its schemas, its ADRs); this repo owns the
runtime. Until 25/09/2026 it was one server over `~/context`.

## Why uv2nix, and not the four other ways

It is not in nixpkgs, in any channel, and the dependency tree says why nobody bothered:
`fastmcp==4.0.0b1` pinned to a BETA, plus fastembed (ONNX), litellm, sqlite-vec, asyncpg, psycopg
and logfire. Packaging that by hand would mean vendoring dozens of derivations and fighting an
exact pin nixpkgs will never carry.

| Path | Why not |
| --- | --- |
| nixpkgs / by hand | the beta pin alone kills it, and 173 packages is not a weekend |
| `uvx basic-memory` | a fetch with no hash at runtime, which is rule 13 |
| the official container | a Docker daemon in the loop and a digest to chase, for a local CLI |
| the paid cloud | the entire point is that the files stay here |

uv2nix builds a Nix package set FROM a `uv.lock`, so the exact resolution is the pin and every
wheel carries its hash. Measured on 24/08/2026: 173 packages, a 712 MiB closure, and `bm --version`
answering `Basic Memory version: 0.23.0`.

**The workspace here is MINE, not upstream's**, and that is the detail worth keeping.
[`pkgs/basic-memory/pyproject.toml`](../../../pkgs/basic-memory/pyproject.toml) declares ONE
dependency, `basic-memory==0.23.0`, and the `uv.lock` next to it is the pin. Two things fall out
of that:

- Upstream builds with `hatchling` plus `uv-dynamic-versioning`, which reads the version from GIT
  metadata. Building their repo from a tarball would have to fake a tag; taking the PyPI wheel does
  not have the problem at all.
- The bump is one command in the repo, and it is the only way this version moves:

```bash
nix run nixpkgs#uv -- lock --upgrade-package basic-memory --directory pkgs/basic-memory
```

`prerelease = "allow"` sits in that pyproject on purpose: without it uv refuses the resolution
outright, with `Because there is no version of fastmcp==4.0.0b1`. The pre-release is upstream's
choice, and declaring the tolerance in the file is what keeps `uv lock` reproducible from a clean
clone.

Two sdists need a build-system fix, both in `pkgs/basic-memory.nix`: `pybars3` and `pymeta3` never
declared `setuptools`, so uv refuses to guess it. Everything else installs from a wheel.

## Two servers, split at the FAI boundary

A Basic Memory server has no authentication, no read-only mode and no per-folder write limit, and it
exposes every project it knows. Whatever it returns to a cloud-backed client goes to that client's
provider. So the FAI scope gets its OWN server, with its own `BASIC_MEMORY_CONFIG_DIR` and therefore
its own SQLite, and the general server never indexes a FAI file. That holds even if every access
rule around it fails, because the general server has nothing FAI to return. The reasoning, on the
content side, is the context repo's ADR 0006.

| Server | Port | Projects | Clients |
| --- | --- | --- | --- |
| `basic-memory-general` | 8765 | `personal`, `study`, `projects` | codex, agy |
| `basic-memory-fai` | 8766 | `fai` | Claude Code, FAI account |

**The personal Claude account gets NO memory server**, which is a decision and not an omission
(25/09/2026). The FAI account sees only the FAI server, so my personal context never goes through
the organization's workspace. The scope directories do not overlap, so no file is indexed twice.

The projects are declared through `BASIC_MEMORY_PROJECTS`, a JSON object, so the list has one owner
and a client cannot add a project. **THE JSON IS SINGLE-QUOTED in `Environment=`**: unquoted,
systemd strips its double quotes and Basic Memory receives `{personal:{path:...}}`, measured with a
transient unit before the switch.

## HTTP and not stdio, so there is ONE index per directory

`bm mcp` speaks stdio, streamable-http or sse. Stdio is the default everywhere and it is the wrong
default here: each client would SPAWN its own server, so several processes would be indexing and
writing the same SQLite for one directory. That is several owners of one artifact (rules 14 and 15).

So each server is a systemd user unit on `127.0.0.1`, and the CLIs are clients of it. Measured
against the running unit's endpoint, the handshake answers:

```json
{"protocolVersion":"2025-06-18","serverInfo":{"name":"Basic Memory","version":"4.0.0b1"}}
```

Every client supports it: Claude Code takes `"type": "http"`, codex 0.148 takes `codex mcp add
--url` (which writes `[mcp_servers.<name>] url`), and agy reads `~/.gemini/config/mcp_config.json`.
The ports and paths have ONE owner, `my.memory.servers` in the module, and no client holds a literal
(rule 11), except codex's versioned mirror, which cannot read an option.

## The environment is the config

`~/.basic-memory/config.json` carries 88 settings and the app REWRITES it, which is the same
question codex and agy raise. The answer here is neither a symlink nor a generated file: every
setting reads from a `BASIC_MEMORY_<KEY>` variable, so the unit's `Environment=` owns what I
declare and the file stays state. The tool itself confirms who won:

```text
$ bm config get auto_update
auto_update = False
Overridden by $BASIC_MEMORY_AUTO_UPDATE = false
```

What is declared, and why:

| Variable | Why |
| --- | --- |
| `BASIC_MEMORY_CONFIG_DIR` | `~/.basic-memory/<server>`, so each server has its own config file and SQLite |
| `BASIC_MEMORY_PROJECTS` | the server's projects, one per scope directory, as JSON |
| `BASIC_MEMORY_PROJECT_ROOT` | `knowledge/`: every project stays under it, so an agent cannot index some other corner of my home |
| `BASIC_MEMORY_DEFAULT_PROJECT` | the server's first project, the one a client gets when it names none |
| `BASIC_MEMORY_AUTO_UPDATE` | the store is read-only, so its updater could only nag |
| `BASIC_MEMORY_INDEX_CHANGES` | what I edit in Obsidian reaches the index; pinned because a default is upstream's to change |

## Traps measured on the way in

**The first start is what creates the project** (measured with the single server, 24/08/2026).
Before the server has run once, `bm tool write-note` fails with `Project not found: 'main'. No
projects are set up yet`, even though
`bm project list` shows `main` and `bm project add` answers `Project 'main' already exists`. The
config knows the project and the database does not, and the MCP server's lifespan is what
reconciles them. So the unit comes first and the CLI second.

**Semantic search is on by default and its model is not here.** `semantic_search_enabled` is true
with fastembed and `bge-small-en-v1.5`, which downloads at first use into a cache. Nothing had to
download for the search I measured, which came back from the text index, so the embedding path is
lazy. When it does fire it is a runtime fetch into `~/.cache`, the same class of thing as agy's
browser runtime: state, not a declaration.

**The importers are real, and I do not use them.** `import_chatgpt`, `import_claude_conversations`
and `import_claude_projects` exist in the source, and each writes Markdown straight into a
project. An export mixes every scope, FAI included, so that would skip the classification the
context repo requires before anything reaches a committed path (its ADRs 0003 and 0004). The
import is the context repo's own tooling; what stays here is getting the export onto disk, in
[the export guide](../../guides/context-exports.md).

## Verifying the clients, and two answers that look like failures

Measured after the first switch, 24/08/2026, when one server served all three:

| Client | What it says | What it means |
| --- | --- | --- |
| `agy` | `/mcp` prints `Restarted server: basic-memory` | connected |
| codex | `codex mcp list` shows `enabled`, `auth_status: unsupported` | connected; the server advertises no OAuth, which is what a local one should do |
| Claude Code | `claude mcp list` does NOT show it | expected: that command lists CONFIGURED scopes, and both this and the Azure MCP arrive through `--mcp-config` |

The Claude one is worth spelling out because it reads like a bug. The proof it is not: a fresh
session answered `Permission required for mcp__basic-memory__recent_activity`, so the tool was
there all along, and once the permission was declared the same session came back with results. The
Azure MCP has always been invisible to `mcp list` for exactly the same reason.

Re-measured after the split, 25/09/2026, asking each server over MCP (`list_memory_projects`):
8765 answers `personal`, `projects`, `study` and 8766 answers `fai` alone. On the client side,
`claude-fai` carries only the 8766 endpoint, `claude-pessoal` carries none, and agy and codex point
at 8765. The old `basic-memory.service` is gone, and nothing was written into the repository.

**Permissions are split on purpose**, in the FAI account's settings, the only Claude account with a
memory server. The reads and the two ordinary writes (`write_note`, `edit_note`) are allowed,
because a memory that prompts on every read is a memory nobody uses, and a bad note is a
`git revert` away. `delete_note`, `delete_project`, `move_note`,
`create_memory_project`, `list_workspaces` and `fetch` still prompt: the first four destroy or
relocate, and `fetch` is a web request made BY the server, which is not the same thing as reading
my own notes.

## The context repository, and who writes the frontmatter

The knowledge base is its own git repository, with the layout, the frontmatter contract and the
decisions in its own `docs/`. What matters from this side: the servers index `knowledge/<scope>/`
only, and a note must carry the repo's full frontmatter (`id`, `sources`, ...) before its validator
lets it be committed.

**The index writes back into my files**, which surprised me and is correct: with
`ensure_frontmatter_on_sync` the watcher adds `title`, `type` and `permalink` to a Markdown file
the moment it appears. So a note handwritten in Obsidian comes back with a permalink, and a note
written through MCP arrives with one. It touches the frontmatter and never the body. Those three
fields are not the whole contract, so an MCP-written note still fails the repo's validator until it
is completed, and that is the intended gate.

## What is state, and where it lives

| Path | What it is |
| --- | --- |
| `my.memory.dir` | the Markdown. The source of truth, and the thing to keep if the index ever goes |
| `~/.basic-memory/<server>/config.json` | the 88 settings, app-owned, overridden by the unit |
| `~/.basic-memory/<server>/memory.db` | the SQLite index, DERIVED: it can be rebuilt with `bm reindex` |

The index being derived is what makes a backup boring: what matters is the Markdown, which lives
in git. There is no backup of this machine right now (rule 6), so the Markdown's only other copy
is the pushed remote. `~/.basic-memory/config.json` and `memory.db` at the top level belong to the
single server that preceded the split, and are unused after the switch.
