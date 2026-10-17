// The file tree's logic with no React in it: the tree a manifest becomes, the rows a reader sees,
// and what a key does. Pure, so node's test runner covers it: docs/notes/repo/site-sources.md
import type { RelatedFile } from '../../lib/source-manifest.ts';

export interface FolderNode {
  kind: 'folder';
  /** The folder's repo path, which is also its id. */
  id: string;
  /** What the row shows: a chain of single-child folders is ONE row, `modules/home/desktop`. */
  name: string;
  children: TreeNode[];
}

export interface FileNode {
  kind: 'file';
  id: string;
  name: string;
  file: RelatedFile;
}

export type TreeNode = FolderNode | FileNode;

export interface Row {
  id: string;
  kind: TreeNode['kind'];
  name: string;
  depth: number;
  parent?: string;
  file?: RelatedFile;
  expanded?: boolean;
  /** For aria-setsize and aria-posinset, which a flat list needs to read as a tree. */
  size: number;
  position: number;
}

const byName = (a: TreeNode, b: TreeNode) =>
  a.kind === b.kind ? (a.name < b.name ? -1 : a.name > b.name ? 1 : 0) : a.kind === 'folder' ? -1 : 1;

/** The manifest's flat list as a tree, folders first, each level sorted, single-child chains merged. */
export function buildTree(files: RelatedFile[]): TreeNode[] {
  const root: FolderNode = { kind: 'folder', id: '', name: '', children: [] };
  for (const file of files) {
    const segments = file.path.split('/');
    let folder = root;
    for (const [i, segment] of segments.slice(0, -1).entries()) {
      const id = segments.slice(0, i + 1).join('/');
      let next = folder.children.find((c): c is FolderNode => c.kind === 'folder' && c.id === id);
      if (!next) {
        next = { kind: 'folder', id, name: segment, children: [] };
        folder.children.push(next);
      }
      folder = next;
    }
    folder.children.push({ kind: 'file', id: file.path, name: segments.at(-1)!, file });
  }

  const compact = (node: TreeNode): TreeNode => {
    if (node.kind === 'file') return node;
    let folder = node;
    while (folder.children.length === 1 && folder.children[0]!.kind === 'folder') {
      const only = folder.children[0] as FolderNode;
      folder = { ...only, name: `${folder.name}/${only.name}` };
    }
    return { ...folder, children: folder.children.map(compact).toSorted(byName) };
  };
  return root.children.map(compact).toSorted(byName);
}

/** Every folder on the way to a file the page CITES: context stays folded until it is asked for. */
export function defaultExpanded(nodes: TreeNode[]): Set<string> {
  const open = new Set<string>();
  const visit = (node: TreeNode): boolean => {
    if (node.kind === 'file') return node.file.relation !== 'module';
    let cited = false;
    for (const child of node.children) cited = visit(child) || cited;
    if (cited) open.add(node.id);
    return cited;
  };
  for (const node of nodes) visit(node);
  return open;
}

/** Every folder that leads to a match. A filter shows its matches without touching what is folded. */
function matching(nodes: TreeNode[], query: string): Set<string> | undefined {
  if (query === '') return;
  const found = new Set<string>();
  const visit = (node: TreeNode): boolean => {
    if (node.kind === 'file') return node.file.path.toLowerCase().includes(query);
    let hit = false;
    for (const child of node.children) hit = visit(child) || hit;
    if (hit) found.add(node.id);
    return hit;
  };
  for (const node of nodes) visit(node);
  return found;
}

/** The rows on screen, in order. A filter overrides folding while it is typed, and only then. */
export function visibleRows(nodes: TreeNode[], expanded: Set<string>, filter = ''): Row[] {
  const query = filter.trim().toLowerCase();
  const hits = matching(nodes, query);
  const rows: Row[] = [];
  const walk = (level: TreeNode[], depth: number, parent?: string) => {
    const shown = hits ? level.filter((n) => (n.kind === 'folder' ? hits.has(n.id) : n.file.path.toLowerCase().includes(query))) : level;
    for (const [i, node] of shown.entries()) {
      const base = { id: node.id, kind: node.kind, name: node.name, depth, parent, size: shown.length, position: i + 1 };
      if (node.kind === 'file') {
        rows.push({ ...base, file: node.file });
        continue;
      }
      const open = hits !== undefined || expanded.has(node.id);
      rows.push({ ...base, expanded: open });
      if (open) walk(node.children, depth + 1, node.id);
    }
  };
  walk(nodes, 1);
  return rows;
}

export type TreeAction =
  | { focus: string }
  | { toggle: string; focus?: string }
  | { open: string }
  | undefined;

/** What a key does on the focused row, after the WAI-ARIA tree view pattern. */
export function treeKey(rows: Row[], focused: string | undefined, key: string): TreeAction {
  if (rows.length === 0) return;
  const index = Math.max(0, rows.findIndex((r) => r.id === focused));
  const row = rows[index]!;
  switch (key) {
    case 'ArrowDown':
      return { focus: rows[Math.min(index + 1, rows.length - 1)]!.id };
    case 'ArrowUp':
      return { focus: rows[Math.max(index - 1, 0)]!.id };
    case 'Home':
      return { focus: rows[0]!.id };
    case 'End':
      return { focus: rows.at(-1)!.id };
    case 'ArrowRight':
      if (row.kind !== 'folder') return;
      if (!row.expanded) return { toggle: row.id };
      return rows[index + 1]?.parent === row.id ? { focus: rows[index + 1]!.id } : undefined;
    case 'ArrowLeft':
      if (row.kind === 'folder' && row.expanded) return { toggle: row.id };
      return row.parent === undefined ? undefined : { focus: row.parent };
    case 'Enter':
    case ' ':
      return row.kind === 'file' ? { open: row.id } : { toggle: row.id };
  }
}

/** A click the preview may take over: the plain primary one. Anything modified is the browser's. */
export function isPlainClick(event: {
  button: number;
  metaKey: boolean;
  ctrlKey: boolean;
  shiftKey: boolean;
  altKey: boolean;
  defaultPrevented: boolean;
}): boolean {
  return (
    event.button === 0 &&
    !event.metaKey &&
    !event.ctrlKey &&
    !event.shiftKey &&
    !event.altKey &&
    !event.defaultPrevented
  );
}

/** `?source=<path>&line=<n>`, the preview's deep link, read from a URL's search string. */
export function readDeepLink(search: string): { path: string; line?: number } | undefined {
  const params = new URLSearchParams(search);
  const path = params.get('source');
  if (!path) return;
  const line = Number(params.get('line'));
  return Number.isInteger(line) && line > 0 ? { path, line } : { path };
}

/** The same search string with the deep link set, or removed when `path` is undefined. */
export function writeDeepLink(search: string, path?: string, line?: number): string {
  const params = new URLSearchParams(search);
  params.delete('source');
  params.delete('line');
  if (path !== undefined) {
    params.set('source', path);
    if (line !== undefined) params.set('line', String(line));
  }
  const next = params.toString().replaceAll('%2F', '/');
  return next === '' ? '' : `?${next}`;
}
