'use client';

// The read-only source viewer: a sheet on the right that leaves the page readable and scrolled
// where it was. Fumadocs' DynamicCodeBlock draws the code with the site's own shiki themes, on a
// highlighter that carries only what the policy can publish, and this file is loaded on the FIRST
// open only: docs/notes/repo/site-sources.md
import { DynamicCodeBlock } from 'fumadocs-ui/components/dynamic-codeblock.core';
import { useCopyButton } from 'fumadocs-ui/utils/use-copy-button';
import {
  Check,
  Copy,
  ExternalLink,
  FileCode,
  FolderTree,
  Link as LinkIcon,
  Maximize2,
  Minimize2,
  X,
} from 'lucide-react';
import type { ShikiTransformer } from 'shiki';
import {
  type CSSProperties,
  type KeyboardEvent,
  type PointerEvent,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { CODE_THEME_DARK, CODE_THEME_LIGHT } from '../../lib/palette.ts';
import { BLOB_BASE, REPO_URL } from '../../lib/repo.ts';
import { type PageManifest, type RelatedFile, REVISION_URL, assetUrl } from '../../lib/source-manifest.ts';
import { FileTree } from './file-tree.tsx';
import { highlighterFor } from './highlighter.ts';
import { useSource } from './provider.tsx';

// Fetched once per visit: a file opened twice is read from here the second time.
const contents = new Map<string, Promise<string>>();
function loadContent(asset: string): Promise<string> {
  const url = assetUrl(asset);
  if (url === undefined) return Promise.reject(new Error('not an asset'));
  let pending = contents.get(asset);
  if (!pending) {
    pending = fetch(url).then((r) => (r.ok ? r.text() : Promise.reject(new Error(`${r.status}`))));
    // A failure is not cached, so Retry really retries.
    pending.catch(() => contents.delete(asset));
    contents.set(asset, pending);
  }
  return pending;
}

// The commit the snapshot was built from, so a GitHub link shows the SAME bytes as the preview.
// A dev tree has none, and the branch stands in for it.
let revision: Promise<string | null> | undefined;
function loadRevision(): Promise<string | null> {
  revision ??= fetch(REVISION_URL)
    .then((r) => (r.ok ? r.json() : null))
    .then((json: { rev?: unknown } | null) =>
      typeof json?.rev === 'string' && /^[0-9a-f]{40}$/.test(json.rev) ? json.rev : null,
    )
    .catch(() => null);
  return revision;
}

function githubUrl(path: string, rev: string | null, line?: number): string {
  const base = rev === null ? BLOB_BASE : `${REPO_URL}/blob/${rev}`;
  return `${base}/${path}${line ? `#L${line}` : ''}`;
}

type Content = { asset: string; status: 'ready'; text: string } | { asset: string; status: 'error' };

const WIDTH_KEY = 'docs-site:source-width';
const TREE_KEY = 'docs-site:source-tree';
const MIN_WIDTH = 360;

function stored(key: string): string | null {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}
function store(key: string, value: string) {
  try {
    localStorage.setItem(key, value);
  } catch {}
}

const iconButton =
  'inline-flex size-8 items-center justify-center rounded-md text-fd-muted-foreground outline-none hover:bg-fd-accent hover:text-fd-accent-foreground focus-visible:ring-2 focus-visible:ring-fd-ring [&_svg]:size-4';

const RELATION_TEXT = {
  direct: 'Cited by this page',
  declared: 'Its header points at this page',
  module: 'Part of a module this page cites',
} as const;

export function SourcePreview({ file, line, manifest }: { file: RelatedFile; line?: number; manifest: PageManifest }) {
  const source = useSource()!;
  const [content, setContent] = useState<Content>();
  const [attempt, setAttempt] = useState(0);
  const [rev, setRev] = useState<string | null>(null);
  const [width, setWidth] = useState<number>();
  const [expanded, setExpanded] = useState(false);
  const [showTree, setShowTree] = useState(false);
  const panel = useRef<HTMLElement>(null);
  const heading = useRef<HTMLHeadingElement>(null);
  const body = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const saved = Number(stored(WIDTH_KEY));
    if (saved >= MIN_WIDTH) setWidth(saved);
    setShowTree(stored(TREE_KEY) === 'true');
    void loadRevision().then(setRev);
    // Focus moves INTO the sheet once, so Tab and Esc work from the start.
    heading.current?.focus({ preventScroll: true });
  }, []);

  useEffect(() => {
    if (file.asset === null) return;
    let live = true;
    const asset = file.asset;
    loadContent(asset).then(
      (text) => live && setContent({ asset, status: 'ready', text }),
      () => live && setContent({ asset, status: 'error' }),
    );
    return () => {
      live = false;
    };
  }, [file.asset, attempt]);

  // Esc closes from anywhere but another dialog, which owns its own Esc (the search, the drawer).
  useEffect(() => {
    const onKey = (event: globalThis.KeyboardEvent) => {
      if (event.key !== 'Escape' || event.defaultPrevented) return;
      if (event.target instanceof Element && event.target.closest('dialog, [role="dialog"]')) return;
      source.close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [source]);

  const status =
    file.asset === null
      ? 'too-large'
      : content?.asset !== file.asset
        ? 'loading'
        : content.status === 'error'
          ? 'error'
          : content.text === ''
            ? 'empty'
            : 'ready';
  const text = content?.status === 'ready' ? content.text : '';

  // The line a link pointed at: marked by shiki, then scrolled to once it exists in the DOM.
  const transformers = useMemo<ShikiTransformer[]>(
    () => [
      {
        name: 'source-preview-lines',
        line(node, number) {
          node.properties['data-line'] = number;
          if (number === line) this.addClassToHast(node, 'highlighted');
        },
      },
    ],
    [line],
  );
  useEffect(() => {
    const container = body.current;
    if (!container || status !== 'ready' || line === undefined) return;
    const scroll = () => {
      const target = container.querySelector(`[data-line="${line}"]`);
      if (!target) return false;
      const offset = target.getBoundingClientRect().top - container.getBoundingClientRect().top;
      container.scrollTop += offset - container.clientHeight / 3;
      return true;
    };
    if (scroll()) return;
    const observer = new MutationObserver(() => scroll() && observer.disconnect());
    observer.observe(container, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [status, line, file.path]);

  const [pathCopied, copyPath] = useCopyButton(() => navigator.clipboard.writeText(file.path));
  const [textCopied, copyText] = useCopyButton(() => navigator.clipboard.writeText(text));

  const resize = (clientX: number) => {
    const max = window.innerWidth - 120;
    const next = Math.round(Math.min(max, Math.max(MIN_WIDTH, window.innerWidth - clientX)));
    setWidth(next);
    return next;
  };
  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    setExpanded(false);
  };
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture(event.pointerId)) resize(event.clientX);
  };
  const onPointerUp = () => width && store(WIDTH_KEY, String(width));
  const onResizeKey = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.key === 'ArrowLeft' ? 32 : event.key === 'ArrowRight' ? -32 : 0;
    if (step === 0) return;
    event.preventDefault();
    const current = panel.current?.getBoundingClientRect().width ?? MIN_WIDTH;
    store(WIDTH_KEY, String(resize(window.innerWidth - current - step)));
  };

  const toggleTree = () => {
    setShowTree(!showTree);
    store(TREE_KEY, String(!showTree));
  };

  const name = file.path.slice(file.path.lastIndexOf('/') + 1);
  const github = githubUrl(file.path, rev, line);
  const cited = file.sections.filter((id) => manifest.sections[id] !== undefined);

  return (
    <aside
      ref={panel}
      aria-label={`Source of ${file.path}`}
      style={{ '--source-width': width ? `${width}px` : 'min(52rem, 62vw)' } as CSSProperties}
      className={[
        'source-sheet fixed inset-y-0 right-0 z-40 flex w-full flex-col border-s bg-fd-background text-fd-foreground shadow-2xl',
        expanded ? '' : 'md:w-(--source-width)',
      ].join(' ')}
    >
      {!expanded && (
        <div
          role="separator"
          aria-orientation="vertical"
          aria-label="Resize the source preview"
          aria-valuenow={width}
          aria-valuemin={MIN_WIDTH}
          tabIndex={0}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onKeyDown={onResizeKey}
          className="absolute inset-y-0 -start-1 z-10 w-2 cursor-col-resize touch-none outline-none hover:bg-fd-primary/30 focus-visible:bg-fd-primary/40 max-md:hidden"
        />
      )}
      <header className="flex flex-col gap-1 border-b px-4 py-3">
        <div className="flex items-center gap-2">
          <FileCode aria-hidden className="size-4 shrink-0 text-fd-muted-foreground" />
          <h2 ref={heading} tabIndex={-1} className="truncate text-sm font-semibold outline-none">
            {name}
          </h2>
          <span className="shrink-0 rounded bg-fd-muted px-1.5 py-0.5 font-mono text-xs text-fd-muted-foreground">
            {file.lang}
          </span>
          <div className="ms-auto flex shrink-0 items-center">
            <button type="button" onClick={toggleTree} aria-pressed={showTree} aria-label="Show the file tree" title="Files" className={iconButton}>
              <FolderTree aria-hidden />
            </button>
            <button type="button" onClick={copyPath} aria-label="Copy the path" title="Copy the path" className={iconButton}>
              {pathCopied ? <Check aria-hidden /> : <LinkIcon aria-hidden />}
            </button>
            <button
              type="button"
              onClick={copyText}
              disabled={status !== 'ready'}
              aria-label="Copy the file's content"
              title="Copy the content"
              className={`${iconButton} disabled:opacity-40`}
            >
              {textCopied ? <Check aria-hidden /> : <Copy aria-hidden />}
            </button>
            <a href={github} target="_blank" rel="noreferrer noopener" aria-label="Open on GitHub" title="Open on GitHub" className={iconButton}>
              <ExternalLink aria-hidden />
            </a>
            <button
              type="button"
              onClick={() => setExpanded(!expanded)}
              aria-pressed={expanded}
              aria-label="Use the full width"
              title={expanded ? 'Restore the width' : 'Use the full width'}
              className={`${iconButton} max-md:hidden`}
            >
              {expanded ? <Minimize2 aria-hidden /> : <Maximize2 aria-hidden />}
            </button>
            <button type="button" onClick={source.close} aria-label="Close the preview (Esc)" title="Close (Esc)" className={iconButton}>
              <X aria-hidden />
            </button>
          </div>
        </div>
        <p className="truncate font-mono text-xs text-fd-muted-foreground" title={file.path}>
          {file.path}
          {line !== undefined && `:${line}`}
        </p>
        <p className="text-xs text-fd-muted-foreground">
          {RELATION_TEXT[file.relation]}
          {cited.length > 0 && ', under '}
          {cited.map((id, i) => (
            <span key={id}>
              {i > 0 && ', '}
              <a href={`#${id}`} className="text-fd-foreground underline decoration-dotted underline-offset-2 hover:text-fd-primary">
                {manifest.sections[id]}
              </a>
            </span>
          ))}
        </p>
      </header>
      <div className="relative flex min-h-0 flex-1">
        {showTree && (
          <FileTree
            manifest={manifest}
            selected={file.path}
            onOpen={(path) => source.open(path)}
            className="w-60 shrink-0 border-e p-2 max-md:absolute max-md:inset-0 max-md:z-10 max-md:w-full max-md:bg-fd-background"
          />
        )}
        <div ref={body} className="min-w-0 flex-1 overflow-auto overscroll-contain">
          {status === 'loading' && <p className="p-4 text-sm text-fd-muted-foreground">Loading {name}...</p>}
          {status === 'empty' && <p className="p-4 text-sm text-fd-muted-foreground">This file is empty.</p>}
          {status === 'too-large' && (
            <p className="p-4 text-sm text-fd-muted-foreground">
              {name} is {Math.round(file.bytes / 1024)} KiB, over what the site previews.{' '}
              <a href={github} target="_blank" rel="noreferrer noopener" className="underline">
                Read it on GitHub
              </a>
              .
            </p>
          )}
          {status === 'error' && (
            <div className="flex flex-col items-start gap-2 p-4 text-sm text-fd-muted-foreground">
              <p>{name} could not be loaded.</p>
              <div className="flex gap-3">
                <button type="button" onClick={() => setAttempt(attempt + 1)} className="underline">
                  Try again
                </button>
                <a href={github} target="_blank" rel="noreferrer noopener" className="underline">
                  Read it on GitHub
                </a>
              </div>
            </div>
          )}
          {status === 'ready' && (
            <DynamicCodeBlock
              key={`${file.path}:${line ?? ''}`}
              lang={file.lang}
              // shiki numbers the empty line after a final newline, which is not a line of the file.
              code={text.endsWith('\n') ? text.slice(0, -1) : text}
              codeblock={{
                'data-line-numbers': true,
                allowCopy: false,
                className: 'my-0 rounded-none border-0 bg-transparent',
                viewportProps: { className: 'max-h-none overflow-visible' },
              }}
              highlighter={() => highlighterFor(file.lang, [CODE_THEME_LIGHT, CODE_THEME_DARK])}
              options={{ themes: { light: CODE_THEME_LIGHT, dark: CODE_THEME_DARK }, transformers }}
            />
          )}
        </div>
      </div>
    </aside>
  );
}
