// The file tree's logic: the tree a manifest becomes, folding, filtering, the keyboard, what counts
// as a plain click, and the deep link. docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildTree,
  defaultExpanded,
  isPlainClick,
  readDeepLink,
  treeKey,
  visibleRows,
  writeDeepLink,
} from '../components/source/tree.ts';
import type { RelatedFile, Relation } from '../lib/source-manifest.ts';

const related = (path: string, relation: Relation = 'direct'): RelatedFile => ({
  path,
  relation,
  via: ['link'],
  sections: [],
  lang: 'nix',
  bytes: 1,
  lines: 1,
  asset: '0123456789abcdef.txt',
});

const FILES = [
  related('modules/home/desktop/hypr.nix'),
  related('modules/home/desktop/hypr/hyprland.lua', 'module'),
  related('modules/home/desktop/hypr/lua/keybinds.lua'),
  related('modules/home/desktop/hypr/lua/input.lua', 'module'),
  related('modules/home/desktop/theme/extra.nix', 'module'),
];

describe('buildTree', () => {
  it('merges single-child folder chains and puts folders first', () => {
    const tree = buildTree(FILES);
    assert.equal(tree.length, 1);
    const root = tree[0]!;
    assert.equal(root.kind === 'folder' && root.name, 'modules/home/desktop');
    assert.deepEqual(
      root.kind === 'folder' && root.children.map((c) => c.name),
      ['hypr', 'theme', 'hypr.nix'],
    );
  });

  it('opens only the folders that lead to a cited file', () => {
    const open = defaultExpanded(buildTree(FILES));
    assert.deepEqual([...open].toSorted(), [
      'modules/home/desktop',
      'modules/home/desktop/hypr',
      'modules/home/desktop/hypr/lua',
    ]);
  });
});

describe('visibleRows', () => {
  const tree = buildTree(FILES);

  it('hides what a folded folder holds', () => {
    const rows = visibleRows(tree, new Set(['modules/home/desktop']));
    assert.deepEqual(
      rows.map((r) => [r.name, r.depth]),
      [
        ['modules/home/desktop', 1],
        ['hypr', 2],
        ['theme', 2],
        ['hypr.nix', 2],
      ],
    );
    assert.deepEqual(rows.map((r) => `${r.position}/${r.size}`), ['1/1', '1/3', '2/3', '3/3']);
  });

  it('shows every match of a filter through folded folders, and nothing else', () => {
    const rows = visibleRows(tree, new Set(), 'KEYB');
    assert.deepEqual(
      rows.map((r) => r.name),
      ['modules/home/desktop', 'hypr', 'lua', 'keybinds.lua'],
    );
    assert.deepEqual(visibleRows(tree, new Set(), 'nothing-matches'), []);
  });
});

describe('treeKey', () => {
  const tree = buildTree(FILES);
  const expanded = defaultExpanded(tree);
  const rows = visibleRows(tree, expanded);
  const ids = rows.map((r) => r.id);

  it('moves up and down and to both ends', () => {
    assert.deepEqual(treeKey(rows, ids[0], 'ArrowDown'), { focus: ids[1] });
    assert.deepEqual(treeKey(rows, ids[0], 'ArrowUp'), { focus: ids[0] });
    assert.deepEqual(treeKey(rows, ids[2], 'Home'), { focus: ids[0] });
    assert.deepEqual(treeKey(rows, ids[0], 'End'), { focus: ids.at(-1) });
  });

  it('opens and enters a folder with Right, closes and leaves it with Left', () => {
    const theme = 'modules/home/desktop/theme';
    assert.deepEqual(treeKey(rows, theme, 'ArrowRight'), { toggle: theme });
    const hypr = 'modules/home/desktop/hypr';
    assert.deepEqual(treeKey(rows, hypr, 'ArrowRight'), { focus: rows[ids.indexOf(hypr) + 1]!.id });
    assert.deepEqual(treeKey(rows, hypr, 'ArrowLeft'), { toggle: hypr });
    assert.deepEqual(treeKey(rows, 'modules/home/desktop/hypr.nix', 'ArrowLeft'), { focus: 'modules/home/desktop' });
  });

  it('opens a file and toggles a folder with Enter or Space', () => {
    assert.deepEqual(treeKey(rows, 'modules/home/desktop/hypr.nix', 'Enter'), { open: 'modules/home/desktop/hypr.nix' });
    assert.deepEqual(treeKey(rows, 'modules/home/desktop', ' '), { toggle: 'modules/home/desktop' });
    assert.equal(treeKey(rows, ids[0], 'a'), undefined);
    assert.equal(treeKey([], undefined, 'ArrowDown'), undefined);
  });
});

describe('isPlainClick', () => {
  const plain = { button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, defaultPrevented: false };
  it('takes over the plain primary click only', () => {
    assert.ok(isPlainClick(plain));
    for (const modified of [
      { button: 1 },
      { metaKey: true },
      { ctrlKey: true },
      { shiftKey: true },
      { altKey: true },
      { defaultPrevented: true },
    ]) {
      assert.ok(!isPlainClick({ ...plain, ...modified }), JSON.stringify(modified));
    }
  });
});

describe('the deep link', () => {
  it('reads a path and a line, and only a positive whole line', () => {
    assert.deepEqual(readDeepLink('?source=modules/x.nix&line=12'), { path: 'modules/x.nix', line: 12 });
    assert.deepEqual(readDeepLink('?source=modules/x.nix&line=-3'), { path: 'modules/x.nix' });
    assert.deepEqual(readDeepLink('?source=modules/x.nix&line=1.5'), { path: 'modules/x.nix' });
    assert.equal(readDeepLink('?other=1'), undefined);
  });

  it('writes it in place, keeping every other parameter', () => {
    assert.equal(writeDeepLink('', 'modules/x.nix', 4), '?source=modules/x.nix&line=4');
    assert.equal(writeDeepLink('?a=1&source=old&line=9', 'modules/y.nix'), '?a=1&source=modules/y.nix');
    assert.equal(writeDeepLink('?a=1&source=modules/x.nix'), '?a=1');
    assert.equal(writeDeepLink('?source=modules/x.nix&line=2'), '');
  });
});
