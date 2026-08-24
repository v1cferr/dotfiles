# basic-memory

Modules: [`pkgs/basic-memory.nix`](../../../pkgs/basic-memory.nix),
[`home/services/basic-memory.nix`](../../../home/services/basic-memory.nix)

One memory for the three agent CLIs, instead of one archive each. It is an MCP server over plain
Markdown, so what it indexes is a directory I own and the index is derived.

## The shape, and what is the product

The Markdown in `~/context` is the product. Basic Memory is the INDEX over it: SQLite, a knowledge
graph and MCP tools. That order is deliberate, because it is what keeps this from being a second
lock-in: the day the index stops being worth it, the directory is still there, still readable, and
still openable as an Obsidian vault.

```text
~/context (Markdown, mine)
   |
   +-- Obsidian      the human interface
   +-- basic-memory  the index, over MCP
          |
          +-- Claude Code
          +-- codex
          +-- agy
```

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

## HTTP and not stdio, so there is ONE index

`bm mcp` speaks stdio, streamable-http or sse. Stdio is the default everywhere and it is the wrong
default here: each client would SPAWN its own server, so three processes would be indexing and
writing the same SQLite for one directory. That is three owners of one artifact (rules 14 and 15).

So the server is a systemd user unit on `127.0.0.1`, and the three CLIs are clients of it. Measured
against the running unit's endpoint, the handshake answers:

```json
{"protocolVersion":"2025-06-18","serverInfo":{"name":"Basic Memory","version":"4.0.0b1"}}
```

Every client supports it: Claude Code takes `"type": "http"`, codex 0.148 takes `codex mcp add
--url` (which writes `[mcp_servers.<name>] url`), and agy reads `~/.gemini/config/mcp_config.json`.
The port and the path have ONE owner, `my.memory` in the module, and no client holds a literal
(rule 11).

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
| `BASIC_MEMORY_HOME` | `~/context`, the directory that IS the knowledge base |
| `BASIC_MEMORY_PROJECT_ROOT` | every project stays under it, so an agent cannot index some other corner of my home |
| `BASIC_MEMORY_DEFAULT_PROJECT` | `main`, the one the clients get when they name none |
| `BASIC_MEMORY_AUTO_UPDATE` | the store is read-only, so its updater could only nag |
| `BASIC_MEMORY_INDEX_CHANGES` | what I edit in Obsidian reaches the index; pinned because a default is upstream's to change |

## Traps measured on the way in

**The first start is what creates the project.** Before the server has run once, `bm tool
write-note` fails with `Project not found: 'main'. No projects are set up yet`, even though
`bm project list` shows `main` and `bm project add` answers `Project 'main' already exists`. The
config knows the project and the database does not, and the MCP server's lifespan is what
reconciles them. So the unit comes first and the CLI second.

**Semantic search is on by default and its model is not here.** `semantic_search_enabled` is true
with fastembed and `bge-small-en-v1.5`, which downloads at first use into a cache. Nothing had to
download for the search I measured, which came back from the text index, so the embedding path is
lazy. When it does fire it is a runtime fetch into `~/.cache`, the same class of thing as agy's
browser runtime: state, not a declaration.

**The importers are real, and one is missing.** In the source, not just the docs:
`import_chatgpt`, `import_claude_conversations`, `import_claude_projects` and `import_memory_json`
are registered commands. There is NO Gemini importer, so a Google Takeout needs a converter of my
own before it can land here.

## Verifying the three clients, and two answers that look like failures

Measured after the first switch, 24/08/2026:

| Client | What it says | What it means |
| --- | --- | --- |
| `agy` | `/mcp` prints `Restarted server: basic-memory` | connected |
| codex | `codex mcp list` shows `enabled`, `auth_status: unsupported` | connected; the server advertises no OAuth, which is what a local one should do |
| Claude Code | `claude mcp list` does NOT show it | expected: that command lists CONFIGURED scopes, and both this and the Azure MCP arrive through `--mcp-config` |

The Claude one is worth spelling out because it reads like a bug. The proof it is not: a fresh
session answered `Permission required for mcp__basic-memory__recent_activity`, so the tool was
there all along, and once the permission was declared the same session came back with results. The
Azure MCP has always been invisible to `mcp list` for exactly the same reason.

**Permissions are split on purpose.** The reads and the two ordinary writes (`write_note`,
`edit_note`) are allowed, because a memory that prompts on every read is a memory nobody uses, and
a bad note is a `git revert` away. `delete_note`, `delete_project`, `move_note`,
`create_memory_project`, `list_workspaces` and `fetch` still prompt: the first four destroy or
relocate, and `fetch` is a web request made BY the server, which is not the same thing as reading
my own notes.

## ~/context, and who writes the frontmatter

The knowledge base is its own git repository, with the layout and the rules in its README:
`archive/` is evidence (append-only, per provider and year), `knowledge/` is what is true today
(curated, and allowed to contradict the archive), `sources/` is one note per export, `schema/` is
what `bm schema infer <type> --save` writes.

**The index writes back into my files**, which surprised me and is correct: with
`ensure_frontmatter_on_sync` the watcher adds `title`, `type` and `permalink` to a Markdown file
the moment it appears. So a note handwritten in Obsidian comes back with a permalink, and a note
written through MCP arrives with one. It touches the frontmatter and never the body.

## What is state, and where it lives

| Path | What it is |
| --- | --- |
| `~/context` | the Markdown. The source of truth, and the thing to keep if the index ever goes |
| `~/.basic-memory/config.json` | the 88 settings, app-owned, overridden by the unit |
| `~/.basic-memory/memory.db` | the SQLite index, DERIVED: it can be rebuilt with `bm reindex` |

All of it is under `/home/v1cferr`, so restic already covers it (rule 6). The index being derived
is what makes the backup boring: what matters is the Markdown.
