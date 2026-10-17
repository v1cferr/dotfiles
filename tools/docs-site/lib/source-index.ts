// THE SOURCE INDEX: which repo files each page of docs/ is about, read at BUILD time from the
// markdown's syntax tree and the files' own headers, never guessed from a name: docs/notes/repo/site-sources.md
//
// Pure node plus the markdown parser, so the derivation, the dev script and the tests run one code.
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import GithubSlugger from 'github-slugger';
import type { Definition, Heading, Nodes, Root } from 'mdast';
import { fromMarkdown } from 'mdast-util-from-markdown';
import { gfmFromMarkdown } from 'mdast-util-gfm';
import { gfm } from 'micromark-extension-gfm';
import { listPages } from './page-tree.ts';
import {
  type PageManifest,
  type RelatedFile,
  type Relation,
  RELATIONS,
  type Via,
  isSourceToken,
  lineFromAnchor,
} from './source-manifest.ts';
import {
  POLICY,
  excludedBy,
  isCategory,
  languageOf,
  normalizeRepoPath,
  secretSignature,
} from './source-policy.ts';
import { PAGE_EXTENSION } from './urls.ts';

/** An eligible file, read once. */
export interface SourceFile {
  path: string;
  lang: string;
  bytes: number;
  lines: number;
  /** Absent when the file is over the size cap: it is listed, and GitHub serves it. */
  content?: string;
  asset: string | null;
}

export interface SourceIndex {
  files: Map<string, SourceFile>;
  pages: PageManifest[];
  stats: IndexStats;
  /** What must stop the build: a credential where the policy would publish it. */
  problems: string[];
}

export interface IndexStats {
  pages: number;
  pagesWithFiles: number;
  eligibleFiles: number;
  relations: Record<Relation, number>;
  publishedFiles: number;
  publishedBytes: number;
  tooLarge: string[];
  /** A link, or an inline path under a published root, naming a file that is not there. */
  unresolved: string[];
  /** A reference to a real file the policy keeps out, with the reason. */
  ineligible: string[];
  /** Inline code that matched more than one file of the page's modules, so it stays plain. */
  ambiguous: string[];
}

const DOCS = 'docs';
const HEADING_ID = /\s*\[#(?<slug>[^]+?)]\s*$/;
const DOC_POINTER = /\bdocs\/([A-Za-z0-9_./-]+\.mdx?)\b/g;
const COMMENT = /^\s*(#|\/\/|--|\/\*|\*|<!--)/;
const SKIPPED_DIRS = new Set(['node_modules', '.next', '.source', 'out', '_source', '.git']);

/** Every file under the published roots that the policy allows, sorted. Symlinks never count. */
function walkRoots(repoRoot: string): string[] {
  const found: string[] = [];
  const visit = (rel: string) => {
    const stat = fs.lstatSync(path.join(repoRoot, rel), { throwIfNoEntry: false });
    if (!stat || stat.isSymbolicLink()) return;
    if (stat.isDirectory()) {
      for (const name of fs.readdirSync(path.join(repoRoot, rel)).toSorted()) {
        if (!SKIPPED_DIRS.has(name)) visit(`${rel}/${name}`);
      }
    } else if (stat.isFile() && excludedBy(rel) === undefined) found.push(rel);
  };
  for (const root of POLICY.roots) visit(root);
  return found.toSorted();
}

function readSource(repoRoot: string, rel: string, problems: string[]): SourceFile | undefined {
  const buffer = fs.readFileSync(path.join(repoRoot, rel));
  // A NUL byte is a binary, whatever its extension says.
  if (buffer.includes(0)) return;
  const content = buffer.toString('utf8');
  const secret = secretSignature(content);
  if (secret !== undefined) {
    problems.push(`${rel} looks like it carries ${secret}; exclude it in source-policy.json`);
    return;
  }
  const tooLarge = buffer.length > POLICY.maxBytes;
  const asset = crypto.createHash('sha256').update(buffer).digest('hex').slice(0, 16) + '.txt';
  return {
    path: rel,
    lang: languageOf(rel)!,
    bytes: buffer.length,
    lines: content === '' ? 0 : content.split('\n').length - (content.endsWith('\n') ? 1 : 0),
    content: tooLarge ? undefined : content,
    asset: tooLarge ? null : asset,
  };
}

/** The page each file's leading comment points at: rule 2's header, read in reverse. */
function headerPointers(files: Map<string, SourceFile>): Map<string, string[]> {
  const byPage = new Map<string, string[]>();
  for (const file of files.values()) {
    if (file.content === undefined) continue;
    const lines = file.content.split('\n', 8);
    if (lines[0]?.startsWith('#!')) lines.shift();
    for (const line of lines) {
      if (!COMMENT.test(line)) break;
      for (const [, page] of line.matchAll(DOC_POINTER)) {
        const list = byPage.get(page!) ?? [];
        if (!list.includes(file.path)) list.push(file.path);
        byPage.set(page!, list);
      }
    }
  }
  return byPage;
}

/** What Fumadocs' remark-heading flattens a heading to before slugging it. */
function flatten(node: Nodes): string {
  if ('children' in node) return node.children.map(flatten).join('');
  return 'value' in node && typeof node.value === 'string' ? node.value : '';
}

interface PageRef {
  path: string;
  via: Via;
  section?: string;
  line?: number;
}

interface PageScan {
  links: PageRef[];
  folders: PageRef[];
  /** Inline code shaped like a path that did not name a repo file outright. */
  tokens: { token: string; section?: string }[];
  /** Inline code that named a repo file outright. */
  exact: { token: string; path: string; section?: string }[];
  missing: string[];
}

/**
 * One page's references, in document order, with the section each sits in. The section ids are the
 * ones the site gives the headings: the same slugger, the first H1 left out as remark-doc-title
 * leaves it out, and the `[#id]` override honored.
 */
function scanPage(page: string, source: string, exists: (rel: string) => 'file' | 'dir' | undefined) {
  const tree: Root = fromMarkdown(source, {
    extensions: [gfm()],
    mdastExtensions: [gfmFromMarkdown()],
  });
  const scan: PageScan = { links: [], folders: [], tokens: [], exact: [], missing: [] };
  const definitions = new Map<string, string>();
  for (const node of tree.children) {
    if (node.type === 'definition') definitions.set((node as Definition).identifier, node.url);
  }

  const slugger = new GithubSlugger();
  const titleIndex = tree.children.findIndex((n) => n.type === 'heading' && n.depth === 1);
  const pageDir = path.posix.dirname(page);
  let section: string | undefined;

  const onLink = (url: string) => {
    if (/^[a-z][a-z0-9+.-]*:|^[#/]/i.test(url)) return;
    const hash = url.indexOf('#');
    const [file, anchor] = hash === -1 ? [url, ''] : [url.slice(0, hash), url.slice(hash)];
    if (!file) return;
    let decoded: string;
    try {
      decoded = decodeURI(file);
    } catch {
      return;
    }
    const target = normalizeRepoPath(path.posix.join(DOCS, pageDir, decoded));
    if (target === undefined) return;
    if (target.startsWith(`${DOCS}/`) && PAGE_EXTENSION.test(target)) return;
    const kind = exists(target);
    if (kind === undefined) scan.missing.push(target);
    else if (kind === 'dir') scan.folders.push({ path: target, via: 'folder', section });
    else scan.links.push({ path: target, via: 'link', section, line: lineFromAnchor(anchor) });
  };

  const visit = (node: Nodes, inLink: boolean) => {
    if (node.type === 'heading') {
      if (tree.children[titleIndex] === node) return;
      const last = (node as Heading).children.at(-1);
      const custom = last?.type === 'text' ? HEADING_ID.exec(last.value)?.groups?.slug : undefined;
      section = custom ?? slugger.slug(flatten(node));
      return;
    }
    if (node.type === 'link') onLink(node.url);
    if (node.type === 'linkReference') {
      const url = definitions.get(node.identifier);
      if (url !== undefined) onLink(url);
    }
    if (node.type === 'inlineCode' && !inLink && isSourceToken(node.value)) {
      const target = normalizeRepoPath(node.value);
      const kind = target === undefined ? undefined : exists(target);
      if (kind === 'file') scan.exact.push({ token: node.value, path: target!, section });
      else if (kind === 'dir') scan.folders.push({ path: target!, via: 'folder', section });
      else scan.tokens.push({ token: node.value, section });
    }
    if ('children' in node) {
      const linked = inLink || node.type === 'link' || node.type === 'linkReference';
      for (const child of node.children) visit(child as Nodes, linked);
    }
  };
  visit(tree, false);
  return scan;
}

/** The folder a `<name>.nix` keeps its implementation in, `hypr.nix` next to `hypr/`. */
function moduleDirOf(file: string): string | undefined {
  const name = path.posix.basename(file);
  if (name === 'default.nix' || !name.endsWith('.nix')) return;
  return file.slice(0, -'.nix'.length);
}

class PageFiles {
  private readonly byPath = new Map<string, Omit<RelatedFile, 'lang' | 'bytes' | 'lines' | 'asset'>>();

  add(rel: string, relation: Relation, via: Via, section?: string, line?: number) {
    const found = this.byPath.get(rel);
    if (!found) {
      this.byPath.set(rel, { path: rel, relation, via: [via], sections: section ? [section] : [], line });
      return;
    }
    // The STRONGEST relation wins, and nothing else is lost: every source and section is kept.
    if (RELATIONS.indexOf(relation) < RELATIONS.indexOf(found.relation)) found.relation = relation;
    if (!found.via.includes(via)) found.via.push(via);
    if (section && !found.sections.includes(section)) found.sections.push(section);
    found.line ??= line;
  }

  paths() {
    return [...this.byPath.keys()];
  }

  list(files: Map<string, SourceFile>): RelatedFile[] {
    return [...this.byPath.values()]
      .map((entry) => {
        const file = files.get(entry.path)!;
        const related: RelatedFile = {
          path: entry.path,
          relation: entry.relation,
          via: entry.via.toSorted(),
          sections: entry.sections,
          lang: file.lang,
          bytes: file.bytes,
          lines: file.lines,
          asset: file.asset,
        };
        if (entry.line !== undefined) related.line = entry.line;
        return related;
      })
      .toSorted((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
  }
}

export function buildSourceIndex(repoRoot: string): SourceIndex {
  const problems: string[] = [];
  const files = new Map<string, SourceFile>();
  for (const rel of walkRoots(repoRoot)) {
    const file = readSource(repoRoot, rel, problems);
    if (file) files.set(rel, file);
  }

  const exists = (rel: string): 'file' | 'dir' | undefined => {
    const stat = fs.lstatSync(path.join(repoRoot, rel), { throwIfNoEntry: false });
    if (!stat || stat.isSymbolicLink()) return;
    return stat.isDirectory() ? 'dir' : stat.isFile() ? 'file' : undefined;
  };
  // Everything eligible under a folder, sorted, which is what a folder reference stands for.
  const under = (dir: string) => [...files.keys()].filter((rel) => rel.startsWith(`${dir}/`));

  const declared = headerPointers(files);
  const stats: IndexStats = {
    pages: 0,
    pagesWithFiles: 0,
    eligibleFiles: files.size,
    relations: { direct: 0, declared: 0, module: 0 },
    publishedFiles: 0,
    publishedBytes: 0,
    tooLarge: [],
    unresolved: [],
    ineligible: [],
    ambiguous: [],
  };
  const pages: PageManifest[] = [];
  const docsRoot = path.join(repoRoot, DOCS);

  for (const page of listPages(docsRoot).toSorted()) {
    const scan = scanPage(page, fs.readFileSync(path.join(docsRoot, page), 'utf8'), exists);
    const related = new PageFiles();
    const refs: Record<string, string> = {};
    const truncated: PageManifest['truncated'] = [];
    const where = `docs/${page}`;

    // The POLICY is asked first: in the sandbox a file outside the fence does not exist at all,
    // and it must count the same there as in a dev tree, as kept out and not as missing.
    for (const target of scan.missing) {
      const reason = excludedBy(target);
      if (reason === undefined) stats.unresolved.push(`${where} -> ${target}`);
      else stats.ineligible.push(`${where} -> ${target} (${reason})`);
    }
    for (const ref of scan.links) {
      if (files.has(ref.path)) related.add(ref.path, 'direct', 'link', ref.section, ref.line);
      else stats.ineligible.push(`${where} -> ${ref.path} (${excludedBy(ref.path) ?? 'binary or over a limit'})`);
    }
    for (const ref of scan.exact) {
      if (files.has(ref.path)) {
        related.add(ref.path, 'direct', 'code', ref.section);
        refs[ref.token] = ref.path;
      } else stats.ineligible.push(`${where} -> ${ref.path} (${excludedBy(ref.path) ?? 'binary or over a limit'})`);
    }
    for (const file of declared.get(page) ?? []) related.add(file, 'declared', 'header');

    // A module is a folder the page NAMES, or the folder a cited `<name>.nix` keeps beside it.
    // A module is CONTEXT, so it carries no section: a cited folder must not light up every file
    // in it while that section is on screen.
    const modules = new Set<string>();
    for (const ref of scan.folders) if (!isCategory(ref.path)) modules.add(ref.path);
    for (const file of related.paths()) {
      const dir = moduleDirOf(file);
      if (dir !== undefined && !isCategory(dir) && exists(dir) === 'dir') modules.add(dir);
    }
    for (const dir of [...modules].toSorted()) {
      const inside = under(dir);
      if (inside.length > POLICY.maxModuleFiles) truncated.push({ dir, total: inside.length });
      for (const file of inside.slice(0, POLICY.maxModuleFiles)) related.add(file, 'module', 'folder');
    }

    // A bare `autostart.lua` is clickable ONLY when exactly one file of this page's own modules
    // ends in it: a name alone is never matched against the whole repo.
    const scope = related.paths();
    for (const { token, section } of scan.tokens) {
      const target = normalizeRepoPath(token.replace(/\/$/, ''));
      if (target === undefined) continue;
      const matches = scope.filter((rel) => rel === target || rel.endsWith(`/${target}`));
      if (matches.length === 1) {
        related.add(matches[0]!, 'direct', 'code', section);
        refs[token] = matches[0]!;
      } else if (matches.length > 1) stats.ambiguous.push(`${where}: ${token}`);
      else if (excludedBy(target) === undefined && exists(target) === undefined) {
        stats.unresolved.push(`${where} -> ${target}`);
      }
    }

    const list = related.list(files);
    stats.pages++;
    if (list.length > 0) stats.pagesWithFiles++;
    for (const file of list) stats.relations[file.relation]++;
    pages.push({
      version: 1,
      page,
      files: list,
      refs: Object.fromEntries(Object.entries(refs).toSorted(([a], [b]) => (a < b ? -1 : 1))),
      truncated,
    });
  }

  // Only what some page shows is published: an eligible file nobody cites stays on GitHub alone.
  const shown = new Set(pages.flatMap((page) => page.files.map((file) => file.path)));
  for (const rel of [...shown].toSorted()) {
    const file = files.get(rel)!;
    if (file.asset === null) stats.tooLarge.push(rel);
    else {
      stats.publishedFiles++;
      stats.publishedBytes += file.bytes;
    }
  }
  stats.unresolved = [...new Set(stats.unresolved)].toSorted();
  stats.ineligible = [...new Set(stats.ineligible)].toSorted();
  stats.ambiguous = [...new Set(stats.ambiguous)].toSorted();

  return { files, pages, stats, problems: problems.toSorted() };
}
