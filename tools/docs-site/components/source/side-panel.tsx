'use client';

// The right column, through Fumadocs' documented `slots.toc.main`: the outline it always had, and
// a second tab with the page's source files. Below xl, where the column is hidden, a button opens
// the same tree in a drawer. Why a slot and not a DOM patch: docs/notes/repo/site-sources.md
import { TOCScrollArea, useActiveAnchor, useTOCItems } from 'fumadocs-ui/components/toc';
import * as Block from 'fumadocs-ui/components/toc/block';
import * as Clerk from 'fumadocs-ui/components/toc/clerk';
import * as Normal from 'fumadocs-ui/components/toc/default';
import type { TOCProps } from 'fumadocs-ui/layouts/docs/page/slots/toc';
import { FolderTree, Text, X } from 'lucide-react';
import { type KeyboardEvent, useEffect, useRef, useState } from 'react';
import { FileTree } from './file-tree.tsx';
import { type SourceContextValue, useSource } from './provider.tsx';

const VARIANTS = { normal: Normal, clerk: Clerk, block: Block };
type Tab = 'outline' | 'files';
const TAB_KEY = 'docs-site:toc-tab';

/** The tab a reader last chose, for the next page too. Storage may be off, which is not an error. */
function useTab(): [Tab, (tab: Tab) => void] {
  const [tab, setTab] = useState<Tab>('outline');
  useEffect(() => {
    try {
      if (localStorage.getItem(TAB_KEY) === 'files') setTab('files');
    } catch {}
  }, []);
  const choose = (next: Tab) => {
    setTab(next);
    try {
      localStorage.setItem(TAB_KEY, next);
    } catch {}
  };
  return [tab, choose];
}

function FilesPanel({ source, activeSection }: { source: SourceContextValue | null; activeSection?: string }) {
  if (source === null || source.status === 'loading') {
    return <p className="text-sm text-fd-muted-foreground">Loading the files...</p>;
  }
  if (source.status === 'error' || !source.manifest) {
    return <p className="text-sm text-fd-muted-foreground">The file list could not be loaded.</p>;
  }
  return (
    <FileTree
      manifest={source.manifest}
      selected={source.selected?.path}
      activeSection={activeSection}
      onOpen={(path, opener) => source.open(path, undefined, opener)}
      className="flex-1"
    />
  );
}

const tabClass = (active: boolean) =>
  [
    'inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm outline-none focus-visible:ring-2 focus-visible:ring-fd-ring [&_svg]:size-4',
    active ? 'bg-fd-accent text-fd-accent-foreground' : 'text-fd-muted-foreground hover:text-fd-accent-foreground',
  ].join(' ');

export function SourceTOC({ container, header, footer, style = 'normal', list }: TOCProps) {
  const items = useTOCItems();
  const source = useSource();
  const activeSection = useActiveAnchor();
  const [tab, setTab] = useTab();
  const { TOCItems, TOCItem, TOCEmpty } = VARIANTS[style];
  const count = source?.manifest?.files.length ?? 0;

  // Arrow keys move between the two tabs, as the tabs pattern asks.
  const onTabKey = (event: KeyboardEvent<HTMLDivElement>) => {
    if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
    event.preventDefault();
    const next = tab === 'outline' ? 'files' : 'outline';
    setTab(next);
    document.getElementById(`source-tab-${next}`)?.focus();
  };

  return (
    <>
      <div
        id="source-toc"
        {...container}
        className={[
          // The TOC column's contract with the layout: its grid area, its width variable, and the
          // same breakpoint the default TOC hides at.
          'sticky top-(--fd-docs-row-1) flex h-[calc(var(--fd-docs-height)-var(--fd-docs-row-1))] w-(--fd-toc-width) flex-col pt-12 pe-4 pb-2 [grid-area:toc] max-xl:hidden xl:layout:[--fd-toc-width:268px]',
          container?.className,
        ].join(' ')}
      >
        {header}
        <div role="tablist" aria-label="Page navigation" className="mb-3 flex gap-1" onKeyDown={onTabKey}>
          <button
            type="button"
            role="tab"
            id="source-tab-outline"
            aria-selected={tab === 'outline'}
            aria-controls="source-panel-outline"
            tabIndex={tab === 'outline' ? 0 : -1}
            onClick={() => setTab('outline')}
            className={tabClass(tab === 'outline')}
          >
            <Text aria-hidden />
            On this page
          </button>
          <button
            type="button"
            role="tab"
            id="source-tab-files"
            aria-selected={tab === 'files'}
            aria-controls="source-panel-files"
            tabIndex={tab === 'files' ? 0 : -1}
            onClick={() => setTab('files')}
            className={tabClass(tab === 'files')}
          >
            <FolderTree aria-hidden />
            Files
            {count > 0 && <span className="rounded-full bg-fd-muted px-1.5 text-xs tabular-nums">{count}</span>}
          </button>
        </div>
        {tab === 'outline' ? (
          <div role="tabpanel" id="source-panel-outline" aria-labelledby="source-tab-outline" className="flex min-h-0 flex-1 flex-col">
            <TOCScrollArea>
              <TOCItems {...list}>
                {items.length === 0 && <TOCEmpty />}
                {items.map((item) => (
                  <TOCItem key={item.url} item={item} />
                ))}
              </TOCItems>
            </TOCScrollArea>
          </div>
        ) : (
          <div role="tabpanel" id="source-panel-files" aria-labelledby="source-tab-files" className="flex min-h-0 flex-1 flex-col">
            <FilesPanel source={source} activeSection={activeSection} />
          </div>
        )}
        {footer}
      </div>
      <FilesDrawer source={source} activeSection={activeSection} />
    </>
  );
}

/** Below xl the column is gone, so the tree lives in a native modal dialog: Esc, focus and backdrop come free. */
function FilesDrawer({ source, activeSection }: { source: SourceContextValue | null; activeSection?: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const count = source?.manifest?.files.length ?? 0;
  if (source === null || count === 0) return null;

  return (
    <>
      <button
        ref={trigger}
        id="source-files-button"
        type="button"
        aria-haspopup="dialog"
        onClick={() => dialog.current?.showModal()}
        className="fixed right-4 bottom-4 z-30 inline-flex items-center gap-1.5 rounded-full border bg-fd-card px-3 py-2 text-sm shadow-lg outline-none focus-visible:ring-2 focus-visible:ring-fd-ring xl:hidden [&_svg]:size-4"
      >
        <FolderTree aria-hidden />
        Files
        <span className="tabular-nums text-fd-muted-foreground">{count}</span>
      </button>
      <dialog
        ref={dialog}
        aria-label="Source files of this page"
        className="source-drawer mx-0 mt-auto mb-0 max-h-[75dvh] w-full max-w-none flex-col gap-3 rounded-t-xl border bg-fd-background p-4 text-fd-foreground backdrop:bg-black/50 open:flex xl:hidden"
        onClick={(event) => {
          // A click on the backdrop lands on the dialog itself, never on its content.
          if (event.target === event.currentTarget) dialog.current?.close();
        }}
      >
        <div className="flex items-center justify-between">
          <h2 className="inline-flex items-center gap-1.5 text-sm font-medium [&_svg]:size-4">
            <FolderTree aria-hidden />
            Files of this page
          </h2>
          <button
            type="button"
            onClick={() => dialog.current?.close()}
            aria-label="Close"
            className="rounded-md p-1 text-fd-muted-foreground hover:bg-fd-accent [&_svg]:size-4"
          >
            <X aria-hidden />
          </button>
        </div>
        <FileTree
          manifest={source.manifest!}
          selected={source.selected?.path}
          activeSection={activeSection}
          onOpen={(path) => {
            dialog.current?.close();
            // The drawer's button is where focus goes back to when the preview closes.
            source.open(path, undefined, trigger.current);
          }}
          className="min-h-0 flex-1"
        />
      </dialog>
    </>
  );
}
