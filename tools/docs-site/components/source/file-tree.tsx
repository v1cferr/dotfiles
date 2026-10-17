'use client';

// The related files as a tree: real repo paths, folders to fold, a filter, and the keyboard of a
// WAI-ARIA tree view. Why not Fumadocs' <Folder>: docs/notes/repo/site-sources.md
import { Files } from 'fumadocs-ui/components/files';
import {
  ChevronRight,
  FileCode,
  FileJson,
  FileTerminal,
  FileText,
  Folder,
  FolderOpen,
  Search,
} from 'lucide-react';
import { type KeyboardEvent, useMemo, useRef, useState, useSyncExternalStore } from 'react';
import { TREE_BASE } from '../../lib/repo.ts';
import type { PageManifest, RelatedFile, Relation } from '../../lib/source-manifest.ts';
import { buildTree, defaultExpanded, treeKey, visibleRows } from './tree.ts';

// The folders a reader opened or closed BY HAND, for the whole visit: a choice made on one page
// holds on the next page that shows the same folder. Everything else follows the defaults.
let choices = new Map<string, boolean>();
const listeners = new Set<() => void>();
const subscribe = (listener: () => void) => {
  listeners.add(listener);
  return () => void listeners.delete(listener);
};
const getChoices = () => choices;
function choose(id: string, open: boolean) {
  choices = new Map(choices).set(id, open);
  for (const listener of listeners) listener();
}

const RELATION_LABEL: Record<Relation, string> = {
  direct: 'cited by this page',
  declared: 'its header points at this page',
  module: 'part of a module this page cites',
};

function FileIcon({ file }: { file: RelatedFile }) {
  if (file.lang === 'json' || file.lang === 'jsonc') return <FileJson aria-hidden />;
  if (file.lang === 'markdown') return <FileText aria-hidden />;
  if (file.lang === 'bash') return <FileTerminal aria-hidden />;
  return <FileCode aria-hidden />;
}

const cx = (...classes: (string | false | undefined)[]) => classes.filter(Boolean).join(' ');

export interface FileTreeProps {
  manifest: PageManifest;
  /** The path the preview shows, marked as the selection. */
  selected?: string;
  /** The heading on screen: files cited under it are marked, never reordered or opened. */
  activeSection?: string;
  onOpen: (path: string, opener: HTMLElement) => void;
  className?: string;
}

export function FileTree({ manifest, selected, activeSection, onOpen, className }: FileTreeProps) {
  const nodes = useMemo(() => buildTree(manifest.files), [manifest.files]);
  const defaults = useMemo(() => defaultExpanded(nodes), [nodes]);
  const chosen = useSyncExternalStore(subscribe, getChoices, getChoices);
  const expanded = useMemo(() => {
    const open = new Set(defaults);
    for (const [id, isOpen] of chosen) {
      if (isOpen) open.add(id);
      else open.delete(id);
    }
    return open;
  }, [defaults, chosen]);

  const [filter, setFilter] = useState('');
  const rows = useMemo(() => visibleRows(nodes, expanded, filter), [nodes, expanded, filter]);
  const [focused, setFocused] = useState<string>();
  const elements = useRef(new Map<string, HTMLElement>());

  // ONE row takes Tab (roving tabindex): the focused one, else the selection, else the first.
  const tabStop = rows.find((r) => r.id === focused)?.id ?? rows.find((r) => r.id === selected)?.id ?? rows[0]?.id;
  // The path line names what the reader is ON, and stays empty until they are on something.
  const current = rows.find((r) => r.id === (focused ?? selected));

  const toggle = (id: string) => choose(id, !expanded.has(id));
  const focusRow = (id: string) => {
    setFocused(id);
    elements.current.get(id)?.focus();
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const action = treeKey(rows, tabStop, event.key);
    if (action === undefined) return;
    event.preventDefault();
    if ('open' in action) onOpen(action.open, elements.current.get(action.open)!);
    else if ('toggle' in action) toggle(action.toggle);
    else focusRow(action.focus);
  };

  if (manifest.files.length === 0) {
    return <p className="text-sm text-fd-muted-foreground">This page cites no source files.</p>;
  }

  return (
    <div className={cx('flex min-h-0 flex-col gap-2', className)}>
      <label className="flex items-center gap-2 rounded-md border bg-fd-background px-2 py-1 text-sm focus-within:ring-2 focus-within:ring-fd-ring">
        <Search className="size-3.5 shrink-0 text-fd-muted-foreground" aria-hidden />
        <span className="sr-only">Filter files by name</span>
        <input
          type="search"
          value={filter}
          onChange={(event) => setFilter(event.target.value)}
          placeholder="Filter files"
          className="w-full min-w-0 bg-transparent outline-none placeholder:text-fd-muted-foreground"
        />
      </label>
      <Files className="min-h-0 overflow-auto p-1">
        <div role="tree" aria-label="Source files of this page" onKeyDown={onKeyDown}>
          {rows.map((row) => {
            const isSelected = row.file !== undefined && row.id === selected;
            const inSection = activeSection !== undefined && row.file?.sections.includes(activeSection);
            return (
              <div
                key={row.id}
                ref={(element) => {
                  if (element) elements.current.set(row.id, element);
                  else elements.current.delete(row.id);
                }}
                role="treeitem"
                aria-level={row.depth}
                aria-setsize={row.size}
                aria-posinset={row.position}
                aria-expanded={row.kind === 'folder' ? row.expanded : undefined}
                aria-selected={row.kind === 'file' ? isSelected : undefined}
                tabIndex={row.id === tabStop ? 0 : -1}
                title={row.file ? `${row.file.path}: ${RELATION_LABEL[row.file.relation]}` : `${row.id}/`}
                onFocus={() => setFocused(row.id)}
                onClick={(event) => {
                  setFocused(row.id);
                  if (row.kind === 'folder') toggle(row.id);
                  else onOpen(row.id, event.currentTarget);
                }}
                style={{ paddingInlineStart: `${0.25 + (row.depth - 1) * 0.75}rem` }}
                className={cx(
                  'flex cursor-pointer flex-row items-center gap-1.5 rounded-md py-1 pe-2 text-sm outline-none',
                  'focus-visible:ring-2 focus-visible:ring-fd-ring [&_svg]:size-4 [&_svg]:shrink-0',
                  isSelected ? 'bg-fd-primary/10 text-fd-primary' : 'hover:bg-fd-accent hover:text-fd-accent-foreground',
                  row.file?.relation === 'module' && !isSelected && 'text-fd-muted-foreground',
                )}
              >
                {row.kind === 'folder' ? (
                  <>
                    <ChevronRight
                      aria-hidden
                      className={cx('!size-3 motion-safe:transition-transform', row.expanded && 'rotate-90')}
                    />
                    {row.expanded ? <FolderOpen aria-hidden /> : <Folder aria-hidden />}
                  </>
                ) : (
                  <>
                    {/* The chevron's width, so a file's icon lines up with its folder's. */}
                    <span aria-hidden className="w-3 shrink-0" />
                    <FileIcon file={row.file!} />
                  </>
                )}
                <span className="truncate">{row.name}</span>
                {inSection && (
                  <span className="ms-auto size-1.5 shrink-0 rounded-full bg-fd-primary">
                    <span className="sr-only">, cited in the section on screen</span>
                  </span>
                )}
              </div>
            );
          })}
          {rows.length === 0 && <p className="px-2 py-1 text-sm text-fd-muted-foreground">No file matches.</p>}
        </div>
      </Files>
      {manifest.truncated.map(({ dir, total }) => (
        <a key={dir} href={`${TREE_BASE}/${dir}`} className="text-xs text-fd-muted-foreground underline">
          {dir}/ has {total} files; the rest are on GitHub
        </a>
      ))}
      {/* Its height is RESERVED: a line appearing on the first press would shift the drawer, which
          sits at the bottom, and the release would land on another row. */}
      <p className="min-h-4 truncate font-mono text-xs text-fd-muted-foreground" title={current?.file?.path ?? current?.id}>
        {current?.file?.path ?? (current ? `${current.id}/` : '')}
      </p>
    </div>
  );
}
