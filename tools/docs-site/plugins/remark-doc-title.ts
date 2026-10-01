// It takes the first H1 OUT of the body, because `lib/summary.ts` already turned it into the page
// title and the layout renders that: without this every page shows its heading twice.
// The markdown on disk keeps its H1, which is what GitHub shows: docs/notes/repo/site.md
import type { Root } from 'mdast';

export function remarkDocTitle() {
  return (tree: Root) => {
    const index = tree.children.findIndex((node) => node.type === 'heading' && node.depth === 1);
    if (index !== -1) tree.children.splice(index, 1);
  };
}
