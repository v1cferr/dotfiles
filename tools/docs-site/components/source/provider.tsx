'use client';

// The page's source context: its manifest, fetched once when the page mounts, and the file the
// preview shows. Keyed by page in the route, so navigating resets it: docs/notes/repo/site-sources.md
import dynamic from 'next/dynamic';
import { type ReactNode, createContext, use, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { type PageManifest, type RelatedFile, isPageManifest, pageManifestUrl } from '../../lib/source-manifest.ts';
import { readDeepLink, writeDeepLink } from './tree.ts';

// The viewer and shiki load on the FIRST open, never with the page.
const SourcePreview = dynamic(() => import('./preview.tsx').then((m) => m.SourcePreview), { ssr: false });

export interface Selection {
  path: string;
  line?: number;
}

export interface SourceContextValue {
  status: 'loading' | 'ready' | 'error';
  manifest?: PageManifest;
  selected?: Selection;
  /** The file, when THIS page's manifest lists it: nothing outside it can be opened. */
  find: (path: string) => RelatedFile | undefined;
  open: (path: string, line?: number, opener?: HTMLElement | null) => void;
  close: () => void;
}

const SourceContext = createContext<SourceContextValue | null>(null);

export function useSource(): SourceContextValue | null {
  return use(SourceContext);
}

/** The deep link lives in the query string, written in place: no navigation, no scroll jump. */
function replaceSearch(path?: string, line?: number) {
  const { pathname, search, hash } = window.location;
  window.history.replaceState(window.history.state, '', pathname + writeDeepLink(search, path, line) + hash);
}

export function SourceProvider({ page, children }: { page: string; children: ReactNode }) {
  const [manifest, setManifest] = useState<PageManifest>();
  const [status, setStatus] = useState<SourceContextValue['status']>('loading');
  const [selected, setSelected] = useState<Selection>();
  const opener = useRef<HTMLElement | null>(null);

  useEffect(() => {
    const url = pageManifestUrl(page);
    const controller = new AbortController();
    if (url === undefined) {
      setStatus('error');
      return;
    }
    fetch(url, { signal: controller.signal })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(`${response.status}`))))
      .then((json: unknown) => {
        if (!isPageManifest(json)) throw new Error('not a manifest');
        setManifest(json);
        setStatus('ready');
        // A deep link opens only a file this page lists: the URL names, the manifest decides.
        const link = readDeepLink(window.location.search);
        if (link && json.files.some((file) => file.path === link.path)) setSelected(link);
      })
      .catch(() => {
        if (!controller.signal.aborted) setStatus('error');
      });
    return () => controller.abort();
  }, [page]);

  const find = useCallback((path: string) => manifest?.files.find((file) => file.path === path), [manifest]);

  const open = useCallback((path: string, line?: number, from?: HTMLElement | null) => {
    opener.current = from ?? (document.activeElement instanceof HTMLElement ? document.activeElement : null);
    setSelected({ path, line });
    replaceSearch(path, line);
  }, []);

  const close = useCallback(() => {
    setSelected(undefined);
    replaceSearch();
    // Back to what opened it, without scrolling the page the reader was in.
    if (opener.current?.isConnected) opener.current.focus({ preventScroll: true });
    opener.current = null;
  }, []);

  const value = useMemo(
    () => ({ status, manifest, selected, find, open, close }),
    [status, manifest, selected, find, open, close],
  );
  const file = selected ? find(selected.path) : undefined;

  return (
    <SourceContext value={value}>
      {children}
      {file && manifest && <SourcePreview file={file} line={selected?.line} manifest={manifest} />}
    </SourceContext>
  );
}
