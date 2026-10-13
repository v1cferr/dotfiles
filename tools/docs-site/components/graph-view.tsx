'use client';

// The map of docs/: a force layout of every page and the links between them, in the palette's
// hues. The library is the ONE dependency decision 0013 admitted: docs/notes/repo/site.md
import { Search } from 'lucide-react';
import dynamic from 'next/dynamic';
import { useTheme } from 'next-themes';
import { useRouter } from 'next/navigation';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { ForceGraphMethods, LinkObject, NodeObject } from 'react-force-graph-2d';
import type { GraphLink, GraphNode } from '../lib/graph.ts';
import { servedUrl } from '../lib/urls.ts';

// Canvas and a DOM measure: it cannot render on the server, and only this page downloads it.
// `dynamic` erases the component's generics, so its own type is put back.
const ForceGraph2D = dynamic(() => import('react-force-graph-2d'), {
  ssr: false,
}) as unknown as typeof import('react-force-graph-2d').default;

type Node = NodeObject<GraphNode>;
type Link = LinkObject<GraphNode, GraphLink>;

// One hue per section, in the sidebar's order; the palette's names, resolved from CSS at runtime.
const HUES = ['blue', 'cyan', 'green', 'yellow', 'orange', 'red', 'magenta', 'purple', 'teal', 'sky', 'pink'];

/** A CSS variable as the browser resolves it, which is what a canvas can paint with. */
function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

/** A link end is an id until the layout runs, and the node object after: both read as the id. */
// A page linked from this many others is a hub, and is named even zoomed out.
const HUB = 18;
// The square root keeps the index page (94 links) a landmark instead of a blot.
const radiusOf = (degree: number) => 1.6 + Math.sqrt(degree) * 0.9;

const endpoint = (end: unknown) => (typeof end === 'object' && end !== null ? (end as Node).id : end) as string;

export function GraphView({
  nodes,
  links,
  groups,
}: {
  nodes: GraphNode[];
  links: GraphLink[];
  groups: string[];
}) {
  const router = useRouter();
  const { resolvedTheme } = useTheme();
  const box = useRef<HTMLDivElement>(null);
  const graph = useRef<ForceGraphMethods<Node, Link>>(undefined);
  const fitted = useRef(false);
  const [size, setSize] = useState({ width: 0, height: 0 });
  const [hover, setHover] = useState<string | null>(null);
  const [focus, setFocus] = useState<string | null>(null);
  const [query, setQuery] = useState('');

  // The force layout MUTATES what it is given, so it gets its own copy, made once.
  const data = useMemo(
    () => ({ nodes: nodes.map((n): Node => ({ ...n })), links: links.map((l): Link => ({ ...l })) }),
    [nodes, links],
  );

  const neighbors = useMemo(() => {
    const found = new Map<string, Set<string>>();
    for (const { source, target } of links) {
      if (!found.has(source)) found.set(source, new Set());
      if (!found.has(target)) found.set(target, new Set());
      found.get(source)!.add(target);
      found.get(target)!.add(source);
    }
    return found;
  }, [links]);

  // Re-read on a theme switch: the canvas does not inherit CSS, so its colors are resolved here.
  const colors = useMemo(() => {
    if (typeof document === 'undefined') return null;
    void resolvedTheme;
    return {
      groups: Object.fromEntries(groups.map((g, i) => [g, cssVar(`--palette-${HUES[i % HUES.length]}`)])),
      text: cssVar('--color-fd-foreground'),
      muted: cssVar('--color-fd-muted-foreground'),
      line: cssVar('--color-fd-border'),
      background: cssVar('--color-fd-background'),
      // A canvas cannot resolve var(), so the font the page actually uses is read off the body.
      font: getComputedStyle(document.body).fontFamily,
    };
  }, [groups, resolvedTheme]);

  // More room than the defaults: 127 pages at the default charge pile into one unreadable knot.
  useEffect(() => {
    const g = graph.current;
    if (!g) return;
    g.d3Force('charge')?.strength(-70);
    g.d3Force('link')?.distance(36);
  }, [size.width]);

  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const observer = new ResizeObserver(([entry]) => {
      setSize({ width: entry!.contentRect.width, height: entry!.contentRect.height });
    });
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const needle = query.trim().toLowerCase();
  const matches = useMemo(
    () => (needle ? new Set(nodes.filter((n) => n.title.toLowerCase().includes(needle)).map((n) => n.id)) : null),
    [needle, nodes],
  );

  /** What is lit: the hovered page and its neighbors, else a search, else a section, else all. */
  const lit = (id: string, group: string): boolean => {
    if (hover) return id === hover || Boolean(neighbors.get(hover)?.has(id));
    if (matches) return matches.has(id);
    if (focus) return group === focus;
    return true;
  };

  const jumpTo = (id: string) => {
    const node = data.nodes.find((n) => n.id === id);
    if (node?.x === undefined || node.y === undefined) return;
    graph.current?.centerAt(node.x, node.y, 600);
    graph.current?.zoom(3, 600);
  };

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <label className="flex min-w-56 flex-1 items-center gap-2 rounded-md border bg-fd-card px-2.5 py-1.5 text-sm sm:flex-none">
          <Search className="size-4 text-fd-muted-foreground" />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              const first = matches && [...matches][0];
              if (event.key === 'Enter' && first) jumpTo(first);
            }}
            placeholder="Find a page, Enter to fly to it"
            className="w-full bg-transparent outline-none placeholder:text-fd-muted-foreground"
          />
        </label>
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Sections">
          {groups.map((group) => (
            <button
              key={group}
              type="button"
              aria-pressed={focus === group}
              onClick={() => setFocus(focus === group ? null : group)}
              className="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs transition-colors hover:bg-fd-accent aria-pressed:border-fd-primary aria-pressed:bg-fd-accent"
            >
              <span
                className="size-2 rounded-full"
                // The variable itself, not its value: the server renders it too, so they agree.
                style={{ background: `var(--palette-${HUES[groups.indexOf(group) % HUES.length]})` }}
              />
              {group}
            </button>
          ))}
        </div>
      </div>

      <div ref={box} className="h-[calc(100dvh-14rem)] min-h-96 overflow-hidden rounded-lg border bg-fd-card">
        {colors && size.width > 0 && (
          <ForceGraph2D<GraphNode, GraphLink>
            ref={graph}
            graphData={data}
            width={size.width}
            height={size.height}
            backgroundColor={colors.background}
            nodeId="id"
            nodeLabel={(node: Node) => `${node.title} · ${node.group}`}
            // The pointer's hit area, matched to the dot that is drawn.
            nodePointerAreaPaint={(node: Node, color, ctx) => {
              ctx.fillStyle = color;
              ctx.beginPath();
              ctx.arc(node.x!, node.y!, radiusOf(node.degree) + 1, 0, 2 * Math.PI);
              ctx.fill();
            }}
            linkColor={(link: Link) => {
              const a = endpoint(link.source);
              const b = endpoint(link.target);
              const touches = hover && (a === hover || b === hover);
              return touches ? colors.muted : colors.line;
            }}
            linkWidth={(link: Link) => (hover && [endpoint(link.source), endpoint(link.target)].includes(hover) ? 1.6 : 0.6)}
            cooldownTicks={180}
            onEngineStop={() => {
              // Once, on the first settle: a later stop must not yank the view the reader chose.
              if (!fitted.current) graph.current?.zoomToFit(400, 40);
              fitted.current = true;
            }}
            onNodeHover={(node: Node | null) => {
              setHover(node?.id ?? null);
              if (box.current) box.current.style.cursor = node ? 'pointer' : 'grab';
            }}
            onNodeClick={(node: Node) => router.push(servedUrl(node.id))}
            nodeCanvasObjectMode={() => 'replace'}
            nodeCanvasObject={(node: Node, ctx, scale) => {
              const on = lit(node.id, node.group);
              const radius = radiusOf(node.degree);
              ctx.globalAlpha = on ? 1 : 0.15;
              ctx.beginPath();
              ctx.arc(node.x!, node.y!, radius, 0, 2 * Math.PI);
              ctx.fillStyle = colors.groups[node.group] ?? colors.muted;
              ctx.fill();

              // A label when there is room for it, or when the page is the one being looked at.
              const named = node.id === hover || (matches?.has(node.id) ?? false);
              if (on && (named || scale > 3 || node.degree >= HUB)) {
                const font = Math.max(10 / scale, 1.5);
                ctx.font = `${named ? 600 : 400} ${font}px ${colors.font}`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'top';
                ctx.fillStyle = named ? colors.text : colors.muted;
                ctx.fillText(node.title, node.x!, node.y! + radius + 1.5);
              }
              ctx.globalAlpha = 1;
            }}
          />
        )}
      </div>

      <p className="text-xs text-fd-muted-foreground">
        {nodes.length} pages, {links.length} links between them. Hover a page to light its neighbors, click to
        open it, scroll to zoom, drag to move. A section chip isolates that section.
      </p>
    </div>
  );
}
