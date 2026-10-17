'use client';

// What a marked link or code span becomes: the same element as before until the page's manifest
// says the file is real, and then a plain click opens the preview while every other click stays
// the browser's. With no JS, nothing changes at all: docs/notes/repo/site-sources.md
import Link from 'fumadocs-core/link';
import type { ComponentProps, MouseEvent } from 'react';
import { BLOB_BASE } from '../../lib/repo.ts';
import { useSource } from './provider.tsx';
import { isPlainClick } from './tree.ts';

const HINT = 'Opens a preview here. Ctrl or Cmd and click opens it on GitHub.';

type Marked<T> = T & Record<`data-${string}`, string | undefined>;

export function SourceLink({
  'data-source-path': path,
  'data-source-line': line,
  onClick,
  ...props
}: Marked<ComponentProps<typeof Link>>) {
  const source = useSource();
  const previewable = path !== undefined && source?.find(path) !== undefined;
  return (
    <Link
      {...props}
      data-source-preview={previewable ? '' : undefined}
      title={previewable ? HINT : props.title}
      onClick={(event: MouseEvent<HTMLAnchorElement>) => {
        onClick?.(event);
        if (!previewable || !isPlainClick(event)) return;
        event.preventDefault();
        source!.open(path, line === undefined ? undefined : Number(line), event.currentTarget);
      }}
    />
  );
}

export function SourceCode({ 'data-source-ref': token, ...props }: Marked<ComponentProps<'code'>>) {
  const source = useSource();
  const path = token === undefined ? undefined : source?.manifest?.refs[token];
  // Not a file this page's index resolved: inline code, exactly as it was.
  if (path === undefined || source?.find(path) === undefined) return <code {...props} />;
  return (
    <a
      href={`${BLOB_BASE}/${path}`}
      target="_blank"
      rel="noreferrer noopener"
      data-source-preview=""
      title={HINT}
      onClick={(event) => {
        if (!isPlainClick(event)) return;
        event.preventDefault();
        source.open(path, undefined, event.currentTarget);
      }}
    >
      <code {...props} />
    </a>
  );
}
