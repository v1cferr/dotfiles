// The link rewriter, now that it also marks source references: every href it wrote before is
// unchanged, and a mark appears only where the preview may act. docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import path from 'node:path';
import { describe, it } from 'node:test';
import type { Link, Nodes, Root } from 'mdast';
import { fromMarkdown } from 'mdast-util-from-markdown';
import type { VFile } from 'vfile';
import { remarkRepoLinks } from '../plugins/remark-repo-links.ts';
import { BLOB_BASE, TREE_BASE } from '../lib/repo.ts';

const ROOT = '/repo/docs';

function run(markdown: string, page = 'notes/desktop/hypr.md'): Root {
  const tree = fromMarkdown(markdown);
  const transform = remarkRepoLinks({ root: ROOT, indexed: new Set(['notes', 'history']) });
  transform(tree, { path: path.join(ROOT, page) } as VFile);
  return tree;
}

function all<T extends Nodes>(node: Nodes, type: T['type'], found: T[] = []): T[] {
  if (node.type === type) found.push(node as T);
  if ('children' in node) for (const child of node.children) all(child as Nodes, type, found);
  return found;
}

const props = (node: Nodes) => (node.data as { hProperties?: Record<string, string> } | undefined)?.hProperties;

describe('remarkRepoLinks', () => {
  it('rewrites hrefs exactly as before', () => {
    const links = all<Link>(
      run(
        [
          '[module](../../../modules/home/desktop/hypr.nix)',
          '[line](../../../modules/home/desktop/hypr.nix#L12)',
          '[page](keybinds.md#the-binds)',
          '[folder page](../)',
          '[folder](../../../modules/home/desktop/hypr/)',
          '[anchor](#the-lua-format)',
          '[site](https://wiki.hypr.land)',
          '[root](/graph)',
        ].join('\n\n'),
      ),
      'link',
    );
    assert.deepEqual(
      links.map((l) => l.url),
      [
        `${BLOB_BASE}/modules/home/desktop/hypr.nix`,
        `${BLOB_BASE}/modules/home/desktop/hypr.nix#L12`,
        '/notes/desktop/keybinds#the-binds',
        '/notes',
        `${TREE_BASE}/modules/home/desktop/hypr`,
        '#the-lua-format',
        'https://wiki.hypr.land',
        '/graph',
      ],
    );
  });

  it('marks a blob link with its repo path and line, and nothing else', () => {
    const links = all<Link>(
      run('[a](../../../modules/home/desktop/hypr.nix#L12) [b](keybinds.md) [c](https://x.dev/a.nix) [d](../../../modules/)'),
      'link',
    );
    assert.deepEqual(props(links[0]!), {
      'data-source-path': 'modules/home/desktop/hypr.nix',
      'data-source-line': '12',
    });
    for (const link of links.slice(1)) assert.equal(props(link), undefined, link.url);
  });

  it('marks a path-shaped code span, never one inside a link or a heading', () => {
    const tree = run(
      [
        '## The `hypr.nix` module',
        '',
        '`modules/home/desktop/hypr.nix`, `autostart.lua`, `hyprctl reload`, and',
        '[`keybinds.lua`](../../../modules/home/desktop/hypr/lua/keybinds.lua).',
      ].join('\n'),
    );
    const marked = all<Nodes & { value: string }>(tree, 'inlineCode').map((c) => [c.value, props(c)?.['data-source-ref']]);
    assert.deepEqual(marked, [
      ['hypr.nix', undefined],
      ['modules/home/desktop/hypr.nix', 'modules/home/desktop/hypr.nix'],
      ['autostart.lua', 'autostart.lua'],
      ['hyprctl reload', undefined],
      ['keybinds.lua', undefined],
    ]);
  });
});
