'use client';

// A rendered diagram, opened full screen with zoom and pan. Built on a native <dialog> and pointer
// events, so it adds nothing to the lockfile (decision 0010): docs/notes/repo/site.md
import { Download, Maximize2, Minus, Plus, Scan, X } from 'lucide-react';
import { type ReactNode, useCallback, useEffect, useRef, useState } from 'react';

const MIN = 0.2;
const MAX = 8;
const STEP = 1.25;

type View = { scale: number; x: number; y: number };

/** The diagram's own size, read off its viewBox: mermaid writes `width="100%"` and a max-width. */
function naturalSize(svg: SVGSVGElement): { width: number; height: number } {
  const box = svg.viewBox.baseVal;
  if (box && box.width > 0) return { width: box.width, height: box.height };
  const rect = svg.getBoundingClientRect();
  return { width: rect.width, height: rect.height };
}

const clamp = (scale: number) => Math.min(MAX, Math.max(MIN, scale));

export function DiagramViewer({
  svg,
  title,
  children,
}: {
  svg: string;
  title: string;
  children: ReactNode;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const stage = useRef<HTMLDivElement>(null);
  const content = useRef<HTMLDivElement>(null);
  const drag = useRef<{ x: number; y: number } | null>(null);
  const [view, setView] = useState<View>({ scale: 1, x: 0, y: 0 });
  // The copy of the svg exists only while the dialog is open: a page draws each diagram ONCE.
  const [opened, setOpened] = useState(false);

  /** Scaled to fit the screen with a margin, and centered: what "reset" goes back to. */
  const fit = useCallback(() => {
    const box = stage.current?.getBoundingClientRect();
    const drawn = content.current?.querySelector('svg');
    if (!box || !drawn) return;
    const { width, height } = naturalSize(drawn);
    drawn.setAttribute('width', String(width));
    drawn.setAttribute('height', String(height));
    drawn.style.maxWidth = 'none';
    const scale = clamp(Math.min((box.width * 0.92) / width, (box.height * 0.92) / height));
    setView({ scale, x: (box.width - width * scale) / 2, y: (box.height - height * scale) / 2 });
  }, []);

  /** Zoom by a factor around a point of the stage, so what is under the cursor stays put. */
  const zoomAt = useCallback((factor: number, px?: number, py?: number) => {
    const box = stage.current?.getBoundingClientRect();
    if (!box) return;
    const cx = px ?? box.width / 2;
    const cy = py ?? box.height / 2;
    setView((v) => {
      const scale = clamp(v.scale * factor);
      const k = scale / v.scale;
      return { scale, x: cx - (cx - v.x) * k, y: cy - (cy - v.y) * k };
    });
  }, []);

  useEffect(() => {
    if (!opened) return;
    dialog.current?.showModal();
    // After the dialog lays out, or the stage has no size to fit into.
    requestAnimationFrame(fit);
  }, [opened, fit]);

  const download = () => {
    const blob = new Blob([svg], { type: 'image/svg+xml' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `${title.replace(/[^\w-]+/g, '-').toLowerCase() || 'diagram'}.svg`;
    link.click();
    URL.revokeObjectURL(link.href);
  };

  // The wheel listener is NOT passive, or the page scrolls behind the dialog instead of zooming.
  useEffect(() => {
    const el = stage.current;
    if (!opened || !el) return;
    const onWheel = (event: WheelEvent) => {
      event.preventDefault();
      const box = el.getBoundingClientRect();
      zoomAt(event.deltaY < 0 ? 1.1 : 1 / 1.1, event.clientX - box.left, event.clientY - box.top);
    };
    el.addEventListener('wheel', onWheel, { passive: false });
    return () => el.removeEventListener('wheel', onWheel);
  }, [opened, zoomAt]);

  const onKey = (event: React.KeyboardEvent) => {
    if (event.key === '+' || event.key === '=') zoomAt(STEP);
    else if (event.key === '-') zoomAt(1 / STEP);
    else if (event.key === '0') fit();
  };

  const button =
    'inline-flex size-8 items-center justify-center rounded-md text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-accent-foreground';

  return (
    <div className="group relative">
      {/* The diagram on the page is itself the way in, besides the button. */}
      <div
        role="button"
        tabIndex={-1}
        className="cursor-zoom-in"
        onClick={() => setOpened(true)}
        title="Click to open full screen"
      >
        {children}
      </div>
      <button
        type="button"
        onClick={() => setOpened(true)}
        aria-label={`Open "${title}" full screen`}
        title="Open full screen (zoom and pan)"
        className={`${button} absolute top-2 right-2 border bg-fd-card opacity-70 group-hover:opacity-100 focus-visible:opacity-100`}
      >
        <Maximize2 className="size-4" />
      </button>

      {opened && (
        <dialog
          ref={dialog}
          aria-label={title}
          onKeyDown={onKey}
          onClose={() => setOpened(false)}
          className="m-0 h-dvh max-h-none w-dvw max-w-none bg-fd-background p-0 text-fd-foreground backdrop:bg-black/60"
        >
          <div className="flex h-full flex-col">
            <div className="flex items-center gap-1 border-b px-3 py-2">
              <span className="mr-auto truncate text-sm font-medium">{title}</span>
              <span className="mr-2 hidden text-xs text-fd-muted-foreground tabular-nums sm:inline">
                {Math.round(view.scale * 100)}%
              </span>
              <button type="button" className={button} onClick={() => zoomAt(1 / STEP)} title="Zoom out (-)">
                <Minus className="size-4" />
              </button>
              <button type="button" className={button} onClick={() => zoomAt(STEP)} title="Zoom in (+)">
                <Plus className="size-4" />
              </button>
              <button type="button" className={button} onClick={fit} title="Fit to screen (0)">
                <Scan className="size-4" />
              </button>
              <button type="button" className={button} onClick={download} title="Download the SVG">
                <Download className="size-4" />
              </button>
              <button type="button" className={button} onClick={() => dialog.current?.close()} title="Close (Esc)">
                <X className="size-4" />
              </button>
            </div>

            <div
              ref={stage}
              className="relative flex-1 cursor-grab touch-none overflow-hidden select-none active:cursor-grabbing"
              onPointerDown={(event) => {
                event.currentTarget.setPointerCapture(event.pointerId);
                drag.current = { x: event.clientX - view.x, y: event.clientY - view.y };
              }}
              onPointerMove={(event) => {
                const start = drag.current;
                if (start) setView((v) => ({ ...v, x: event.clientX - start.x, y: event.clientY - start.y }));
              }}
              onPointerUp={() => {
                drag.current = null;
              }}
              onDoubleClick={(event) => {
                const box = event.currentTarget.getBoundingClientRect();
                zoomAt(STEP * STEP, event.clientX - box.left, event.clientY - box.top);
              }}
            >
              <div
                ref={content}
                className="fd-mermaid absolute top-0 left-0 origin-top-left"
                style={{ transform: `translate(${view.x}px, ${view.y}px) scale(${view.scale})` }}
                // The SAME svg the page drew, already sanitized by mermaid's strict security level.
                dangerouslySetInnerHTML={{ __html: svg }}
              />
            </div>

            <p className="border-t px-3 py-1.5 text-center text-xs text-fd-muted-foreground">
              Scroll to zoom · drag to pan · double-click to zoom in · <kbd>0</kbd> fits · <kbd>Esc</kbd>{' '}
              closes
            </p>
          </div>
        </dialog>
      )}
    </div>
  );
}
