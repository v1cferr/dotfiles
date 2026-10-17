// THE CONTRACT between the indexer that writes /_source/ and the browser that reads it: the shapes,
// the URLs, and the one rule for which inline code may become a link: docs/notes/repo/site-sources.md
//
// No node: import here, since the client bundle carries this file.

/** Where the snapshot is served. `pages` joins it under this name, next to the site. */
export const SOURCE_BASE = '/_source';

/**
 * How sure the index is that a file belongs to a page, strongest first. `direct`: the page links it
 * or names its path. `declared`: the file's own header points at the page (rule 2). `module`: it
 * sits inside a module the page names, so it is context and not a citation.
 */
export type Relation = 'direct' | 'declared' | 'module';
export const RELATIONS: Relation[] = ['direct', 'declared', 'module'];

/** What the relation was read from: a link, an inline path, a file header, a folder reference. */
export type Via = 'link' | 'code' | 'header' | 'folder';

export interface RelatedFile {
  path: string;
  relation: Relation;
  via: Via[];
  /** Heading ids of the sections that cite the file, in page order, without the `#`. */
  sections: string[];
  /** The first line a link pointed at (`#L12`), when one did. */
  line?: number;
  lang: string;
  bytes: number;
  lines: number;
  /** The content's file name under `files/`, or null when it is over the size cap. */
  asset: string | null;
}

export interface PageManifest {
  version: 1;
  /** The page, relative to docs/. */
  page: string;
  files: RelatedFile[];
  /** Inline code AS WRITTEN on the page, to the file it was resolved to. Nothing else is clickable. */
  refs: Record<string, string>;
  /** The heading text of every section a file cites, in page order, so a preview can name them. */
  sections: Record<string, string>;
  /** Module folders with more files than the cap: only the first ones are listed. */
  truncated: { dir: string; total: number }[];
}

/** The revision the snapshot was built from, written by `pages`; null on a dirty local build. */
export interface Revision {
  rev: string | null;
}

// A content hash, so a name can never be a path: the browser cannot be steered outside `files/`.
const ASSET = /^[0-9a-f]{16}\.txt$/;
const DOC_PATH = /^[A-Za-z0-9_.@+-]+(?:\/[A-Za-z0-9_.@+-]+)*\.mdx?$/;

/** A page's manifest URL, or undefined for a path that is not a page of docs/. */
export function pageManifestUrl(docPath: string): string | undefined {
  if (!DOC_PATH.test(docPath) || docPath.split('/').includes('..')) return;
  return `${SOURCE_BASE}/pages/${docPath.replace(/\.mdx?$/, '')}.json`;
}

/** An asset's URL, or undefined for a name the indexer could not have written. */
export function assetUrl(asset: string): string | undefined {
  return ASSET.test(asset) ? `${SOURCE_BASE}/files/${asset}` : undefined;
}

export const REVISION_URL = `${SOURCE_BASE}/revision.json`;

// A path-shaped token: no space, no quote, segments of file-name characters.
const TOKEN = /^[A-Za-z0-9_.@+-]+(?:\/[A-Za-z0-9_.@+-]+)*\/?$/;
const HAS_EXTENSION = /\.[A-Za-z0-9]+$/;

/**
 * Whether an inline code span is SHAPED like a file reference: it has a slash, or it ends in an
 * extension. The shape is only a candidate; the index decides whether it names a real file, and
 * the remark plugin and the indexer both ask this, so they cannot disagree on what was a candidate.
 */
export function isSourceToken(value: string): boolean {
  return TOKEN.test(value) && (value.includes('/') || HAS_EXTENSION.test(value));
}

/** `L12` or `L12-L20` from a GitHub-style anchor, as the first line. */
export function lineFromAnchor(anchor: string): number | undefined {
  const match = /^#?L(\d+)(?:-L?\d+)?$/.exec(anchor);
  if (!match) return;
  const line = Number(match[1]);
  return line > 0 ? line : undefined;
}

/** A manifest as the browser received it, checked before anything is fetched on its word. */
export function isPageManifest(value: unknown): value is PageManifest {
  if (typeof value !== 'object' || value === null) return false;
  const manifest = value as PageManifest;
  return (
    manifest.version === 1 &&
    Array.isArray(manifest.files) &&
    manifest.files.every(
      (file) =>
        typeof file.path === 'string' &&
        TOKEN.test(file.path) &&
        !file.path.split('/').includes('..') &&
        RELATIONS.includes(file.relation) &&
        (file.asset === null || ASSET.test(file.asset)),
    ) &&
    typeof manifest.refs === 'object' &&
    manifest.refs !== null &&
    typeof manifest.sections === 'object' &&
    manifest.sections !== null
  );
}
