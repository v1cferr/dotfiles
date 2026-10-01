'use client';

// Mermaid from THIS bundle and never from a CDN (rule 20): the library is a pnpm dependency
// pinned in the lockfile, so no reader fetches a moving pointer: docs/notes/repo/site.md
import { useTheme } from 'next-themes';
import { use, useId, useSyncExternalStore } from 'react';

export function Mermaid({ chart }: { chart: string }) {
  // `false` on the server and during hydration: mermaid measures text, so it needs a DOM.
  const isClient = useSyncExternalStore(
    () => () => {},
    () => true,
    () => false,
  );

  if (!isClient) return null;
  return <MermaidContent chart={chart} />;
}

// `base` is the one theme mermaid lets every color of be set, and each one is READ from the
// Fumadocs preset at render time, so the diagrams follow the site's palette and own none of it.
const TOKENS = {
  primaryColor: 'background',
  primaryBorderColor: 'border',
  primaryTextColor: 'foreground',
  secondaryColor: 'secondary',
  tertiaryColor: 'muted',
  lineColor: 'muted-foreground',
  clusterBkg: 'secondary',
  clusterBorder: 'border',
  edgeLabelBackground: 'card',
  titleColor: 'muted-foreground',
};

/** A token resolved to `rgb(...)` by the browser, which is a form mermaid's color parser reads. */
function themeColors(): Record<string, string> {
  const probe = document.createElement('span');
  document.body.append(probe);
  const colors: Record<string, string> = {};
  for (const [variable, token] of Object.entries(TOKENS)) {
    probe.style.color = `var(--color-fd-${token})`;
    colors[variable] = getComputedStyle(probe).color;
  }
  probe.remove();
  return colors;
}

// The dynamic import is what keeps mermaid out of the pages that draw nothing, which is the same
// trade the vendored copy made when the loader lived in a MkDocs template.
const cache = new Map<string, Promise<unknown>>();

function cachePromise<T>(key: string, create: () => Promise<T>): Promise<T> {
  const cached = cache.get(key);
  if (cached) return cached as Promise<T>;

  const promise = create();
  cache.set(key, promise);
  return promise;
}

function MermaidContent({ chart }: { chart: string }) {
  const id = useId();
  const { resolvedTheme } = useTheme();
  const { default: mermaid } = use(cachePromise('mermaid', () => import('mermaid')));

  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'strict',
    theme: 'base',
    look: 'neo',
    themeVariables: {
      fontFamily: 'var(--font-sans)',
      fontSize: '14px',
      radius: 6,
      dropShadow: 'none',
      useGradient: false,
      background: 'transparent',
      ...themeColors(),
    },
    flowchart: { curve: 'basis', padding: 12, nodeSpacing: 36, rankSpacing: 44, wrappingWidth: 260 },
  });

  const { svg, bindFunctions } = use(
    cachePromise(`${chart}-${resolvedTheme}`, () => mermaid.render(id.replace(/:/g, ''), chart)),
  );

  return (
    <div
      className="fd-mermaid my-6 flex justify-center overflow-x-auto rounded-lg border bg-fd-card p-4"
      ref={(container) => {
        if (container) bindFunctions?.(container);
      }}
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
