"""mkdocs-hooks: it makes the repo's own links work on a site that only serves docs/.

A page here links to the module it documents (`../../../system/services/caddy.nix`), and MkDocs
serves nothing outside `docs_dir`, so those 134 links would each be a build error under
--strict. The hook resolves every relative target against the page's own directory, the same
rule `docs-links` applies, and the ones that escape `docs/` become blob URLs on GitHub, built
from the repo and branch `mkdocs.yml` already declares. The markdown on disk is never touched,
so the same link keeps working when the file is read there.

What was rejected, and the rest of the reasoning: docs/notes/repo/site.md
"""

import posixpath
import re

# An inline markdown link's target: it stops at the first space, so `](path "title")` keeps its
# title, and at `)`, so it never swallows the rest of the line.
MDLINK = re.compile(r"(?<=\]\()([^)\s]+)")

# A fence opener or closer, tracked so a link INSIDE an example is left exactly as written.
FENCE = re.compile(r"^\s*(?:```|~~~)")

EXTERNAL = ("http://", "https://", "mailto:", "#", "/")


def _bases(config):
    """The blob and tree bases, READ from mkdocs.yml so the repo and branch have one owner."""
    repo = (config.repo_url or "").rstrip("/")
    # `edit_uri` is `edit/<branch>/docs/`, the only place the branch is written down. It matters
    # which one: `main` here is a separate orphan history, so its blob URLs are all 404.
    parts = (config.edit_uri or "").strip("/").split("/")
    branch = parts[1] if len(parts) > 2 and parts[0] == "edit" else ""
    if not repo or not branch:
        raise ValueError(f"cannot derive the blob base from repo_url={repo!r} edit_uri={config.edit_uri!r}")
    return f"{repo}/blob/{branch}", f"{repo}/tree/{branch}"


def _rewrite(src_uri, target, index_of, blob, tree):
    """Point a target that escapes docs/ at GitHub; leave everything else to MkDocs."""
    if target.startswith(EXTERNAL):
        return target

    path, _, anchor = target.partition("#")
    if not path:
        return target

    here = posixpath.dirname(src_uri)
    # Relative to docs/. A result starting with `..` is a file the site does not serve.
    inside = posixpath.normpath(posixpath.join(here, path))
    repo_rel = posixpath.normpath(posixpath.join("docs", here, path))
    escapes = inside.startswith("..")

    # A link to a FOLDER (`history/`): MkDocs resolves pages, not directories, so it gets the
    # folder's index page when there is one, and GitHub's tree listing when there is not.
    if path.endswith("/"):
        if not escapes and inside in index_of:
            return posixpath.join(path, index_of[inside]) + (f"#{anchor}" if anchor else "")
        return f"{tree}/{repo_rel}"

    if not escapes:
        return target
    return f"{blob}/{repo_rel}" + (f"#{anchor}" if anchor else "")


def on_page_markdown(markdown, page, config, files, **kwargs):
    """Rewrite the links of one page, skipping fenced code."""
    # The index page of every folder, so a `dir/` link lands on a page instead of nowhere.
    index_of = {}
    for f in files:
        if f.is_documentation_page() and posixpath.basename(f.src_uri) in ("index.md", "README.md"):
            index_of[posixpath.dirname(f.src_uri)] = posixpath.basename(f.src_uri)

    blob, tree = _bases(config)
    src_uri = page.file.src_uri
    out, fenced = [], False
    for line in markdown.split("\n"):
        if FENCE.match(line):
            fenced = not fenced
        out.append(
            line
            if fenced
            else MDLINK.sub(lambda m: _rewrite(src_uri, m.group(0), index_of, blob, tree), line)
        )
    return "\n".join(out)
