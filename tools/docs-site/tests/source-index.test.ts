// The source index, on a fixture repo built per test and on the real tree: what counts as a
// reference, what is merely context, and what never gets in. docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, describe, it } from 'node:test';
import { buildSourceIndex } from '../lib/source-index.ts';
import type { PageManifest } from '../lib/source-manifest.ts';

const fixtures: string[] = [];
after(() => {
  for (const dir of fixtures) fs.rmSync(dir, { recursive: true, force: true });
});

/** A throwaway repo: `files` maps a repo path to its content. */
function repo(files: Record<string, string | Buffer>): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'source-index-'));
  fixtures.push(root);
  for (const [rel, content] of Object.entries(files)) {
    fs.mkdirSync(path.dirname(path.join(root, rel)), { recursive: true });
    fs.writeFileSync(path.join(root, rel), content);
  }
  return root;
}

function page(index: ReturnType<typeof buildSourceIndex>, name: string): PageManifest {
  const found = index.pages.find((p) => p.page === name);
  assert.ok(found, `no manifest for ${name}`);
  return found;
}

const file = (manifest: PageManifest, rel: string) => manifest.files.find((f) => f.path === rel);

// A fixture page's repo path, spelled through a constant: `docs-links` reads a literal docs/ path
// in code as a pointer to a real page, and these pages exist only inside a fixture.
const DOCS = 'docs';

// The shape every fixture shares: a module with a sibling folder, and a page about it.
const BASE = {
  'modules/home/desktop/hypr.nix': '# Hyprland: docs/notes/desktop/hypr.md\n{ }\n',
  'modules/home/desktop/hypr/hyprland.lua': '-- entry\n',
  'modules/home/desktop/hypr/lua/autostart.lua': '-- autostart\n',
  'modules/home/desktop/hypr/lua/keybinds.lua': '-- binds\n',
  'modules/home/desktop/other.nix': '# No note\n{ }\n',
};

describe('buildSourceIndex', () => {
  it('reads links, inline paths and the files that declare the page', () => {
    const root = repo({
      ...BASE,
      'modules/home/desktop/hypr/lua/monitors.lua': '-- Monitors: docs/notes/desktop/hypr.md\n',
      'docs/notes/desktop/hypr.md': [
        '# Hyprland',
        '',
        '`modules/home/desktop/hypr.nix` is the module.',
        '',
        '## The Lua format',
        '',
        'The entrypoint is `hyprland.lua`, see [the binds](../../../modules/home/desktop/hypr/lua/keybinds.lua#L4).',
        '',
      ].join('\n'),
    });
    const hypr = page(buildSourceIndex(root), 'notes/desktop/hypr.md');

    assert.deepEqual(
      hypr.files.map((f) => [f.path, f.relation]),
      [
        ['modules/home/desktop/hypr.nix', 'direct'],
        ['modules/home/desktop/hypr/hyprland.lua', 'direct'],
        ['modules/home/desktop/hypr/lua/autostart.lua', 'module'],
        ['modules/home/desktop/hypr/lua/keybinds.lua', 'direct'],
        ['modules/home/desktop/hypr/lua/monitors.lua', 'declared'],
      ],
    );
    assert.deepEqual(file(hypr, 'modules/home/desktop/hypr/lua/keybinds.lua')?.line, 4);
    assert.deepEqual(file(hypr, 'modules/home/desktop/hypr/lua/keybinds.lua')?.sections, ['the-lua-format']);
    assert.deepEqual(file(hypr, 'modules/home/desktop/hypr.nix')?.via, ['code', 'header']);
    // An inline path in the INTRO sits before every heading: it has no section to light up.
    assert.deepEqual(file(hypr, 'modules/home/desktop/hypr.nix')?.sections, []);
    // A file nobody cites is not context just for sharing a folder with one that is.
    assert.equal(file(hypr, 'modules/home/desktop/other.nix'), undefined);
    assert.deepEqual(hypr.refs, {
      'hyprland.lua': 'modules/home/desktop/hypr/hyprland.lua',
      'modules/home/desktop/hypr.nix': 'modules/home/desktop/hypr.nix',
    });
  });

  it('merges duplicates into one entry that keeps every section, the strongest relation first', () => {
    const root = repo({
      ...BASE,
      [`${DOCS}/notes/a.md`]: [
        '# A',
        '## One',
        '[x](../../modules/home/desktop/hypr.nix) and `modules/home/desktop/hypr.nix`',
        '## Two',
        '[again](../../modules/home/desktop/hypr.nix)',
        '## One',
        '`modules/home/desktop/hypr.nix`',
        '## Custom [#my-id]',
        '`modules/home/desktop/hypr.nix`',
      ].join('\n'),
    });
    const a = page(buildSourceIndex(root), 'notes/a.md');
    const hypr = a.files.filter((f) => f.path === 'modules/home/desktop/hypr.nix');
    assert.equal(hypr.length, 1);
    assert.equal(hypr[0]!.relation, 'direct');
    // github-slugger's numbering for a repeated heading, and the `[#id]` override Fumadocs honors.
    assert.deepEqual(hypr[0]!.sections, ['one', 'two', 'one-1', 'my-id']);
    assert.deepEqual(hypr[0]!.via, ['code', 'link']);
    assert.deepEqual(a.sections, { one: 'One', two: 'Two', 'one-1': 'One', 'my-id': 'Custom' });
  });

  it('resolves a bare name only inside the page own modules, and only when it is unique', () => {
    const root = repo({
      ...BASE,
      'modules/home/desktop/hypr/lua/default.nix': '{ }\n',
      'modules/home/desktop/hypr/default.nix': '{ }\n',
      'modules/home/desktop/bar.nix': '{ }\n',
      [`${DOCS}/notes/a.md`]: [
        '# A',
        '`modules/home/desktop/hypr.nix`, then `autostart.lua`, `lua/keybinds.lua`,',
        '`default.nix` (two of them), `bar.nix` (not in a cited module) and `hyprctl reload`.',
      ].join('\n'),
    });
    const index = buildSourceIndex(root);
    const a = page(index, 'notes/a.md');
    assert.deepEqual(a.refs, {
      'autostart.lua': 'modules/home/desktop/hypr/lua/autostart.lua',
      'lua/keybinds.lua': 'modules/home/desktop/hypr/lua/keybinds.lua',
      'modules/home/desktop/hypr.nix': 'modules/home/desktop/hypr.nix',
    });
    assert.equal(file(a, 'modules/home/desktop/bar.nix'), undefined);
    assert.deepEqual(index.stats.ambiguous, [`${DOCS}/notes/a.md: default.nix`]);
  });

  it('expands a cited folder, but never a category folder', () => {
    const root = repo({
      ...BASE,
      [`${DOCS}/notes/a.md`]: '# A\n\nSee `modules/home/desktop/hypr/` and [the desktop](../../modules/home/desktop/).\n',
    });
    const a = page(buildSourceIndex(root), 'notes/a.md');
    assert.deepEqual(
      a.files.map((f) => f.path),
      [
        'modules/home/desktop/hypr/hyprland.lua',
        'modules/home/desktop/hypr/lua/autostart.lua',
        'modules/home/desktop/hypr/lua/keybinds.lua',
      ],
    );
    assert.ok(a.files.every((f) => f.relation === 'module' && f.sections.length === 0));
  });

  it('caps a large module and says so', () => {
    const many = Object.fromEntries(
      Array.from({ length: 70 }, (_, i) => [`modules/home/desktop/big/f${String(i).padStart(2, '0')}.qml`, 'Item {}\n']),
    );
    const root = repo({ ...many, [`${DOCS}/a.md`]: '# A\n\n`modules/home/desktop/big/`\n' });
    const a = page(buildSourceIndex(root), 'a.md');
    assert.equal(a.files.length, 60);
    assert.deepEqual(a.truncated, [{ dir: 'modules/home/desktop/big', total: 70 }]);
  });

  it('reports missing targets, keeps excluded ones out, and skips what is not a link', () => {
    const root = repo({
      ...BASE,
      'secrets/secrets.yaml': 'a: b\n',
      'modules/nixos/core/secrets.nix': '{ }\n',
      [`${DOCS}/notes/a.md`]: [
        '# A',
        '[gone](../../modules/home/desktop/gone.nix), [secrets](../../secrets/secrets.yaml),',
        '[wiring](../../modules/nixos/core/secrets.nix), `modules/home/desktop/missing.nix`,',
        '[site](https://example.com/modules/home/desktop/hypr.nix), [page](b.md), [anchor](#a).',
        '',
        '```nix',
        '[fenced](../../modules/home/desktop/hypr.nix)',
        '```',
      ].join('\n'),
      [`${DOCS}/notes/b.md`]: '# B\n',
    });
    const index = buildSourceIndex(root);
    assert.deepEqual(page(index, 'notes/a.md').files, []);
    assert.deepEqual(index.stats.unresolved, [
      `${DOCS}/notes/a.md -> modules/home/desktop/gone.nix`,
      `${DOCS}/notes/a.md -> modules/home/desktop/missing.nix`,
    ]);
    assert.deepEqual(index.stats.ineligible, [
      `${DOCS}/notes/a.md -> modules/nixos/core/secrets.nix (name matches secret)`,
      `${DOCS}/notes/a.md -> secrets/secrets.yaml (outside the published roots)`,
    ]);
  });

  it('never indexes a symlink, a binary, or a path that climbs out', () => {
    const root = repo({
      ...BASE,
      'modules/home/desktop/blob.nix': Buffer.from([0x7b, 0x00, 0x7d]),
      [`${DOCS}/a.md`]: '# A\n\n[up](../../../etc/passwd) `modules/home/desktop/blob.nix` `modules/home/desktop/link.nix`\n',
    });
    fs.symlinkSync('/etc/hostname', path.join(root, 'modules/home/desktop/link.nix'));
    const index = buildSourceIndex(root);
    assert.ok(!index.files.has('modules/home/desktop/blob.nix'));
    assert.ok(!index.files.has('modules/home/desktop/link.nix'));
    assert.deepEqual(page(index, 'a.md').files, []);
  });

  it('lists an oversized file without publishing it', () => {
    const root = repo({
      'modules/home/desktop/huge.nix': `# ${'x'.repeat(300 * 1024)}\n`,
      [`${DOCS}/a.md`]: '# A\n\n`modules/home/desktop/huge.nix`\n',
    });
    const index = buildSourceIndex(root);
    const huge = file(page(index, 'a.md'), 'modules/home/desktop/huge.nix');
    assert.equal(huge?.asset, null);
    assert.deepEqual(index.stats.tooLarge, ['modules/home/desktop/huge.nix']);
    assert.equal(index.stats.publishedFiles, 0);
  });

  it('stops on a credential the policy would publish', () => {
    const key = ['-----BEGIN OPENSSH PRIVATE', 'KEY-----'].join(' ');
    const root = repo({ 'modules/home/x/leak.sh': `${key}\n`, [`${DOCS}/a.md`]: '# A\n' });
    assert.deepEqual(buildSourceIndex(root).problems, [
      'modules/home/x/leak.sh looks like it carries a private key block; exclude it in source-policy.json',
    ]);
  });

  it('gives a page with no references an empty manifest, not a missing one', () => {
    const root = repo({ ...BASE, [`${DOCS}/a.md`]: '# A\n\nJust prose, and `nix flake check`.\n' });
    assert.deepEqual(page(buildSourceIndex(root), 'a.md'), {
      version: 1,
      page: 'a.md',
      files: [],
      refs: {},
      sections: {},
      truncated: [],
    });
  });

  it('is deterministic', () => {
    const root = repo({ ...BASE, 'docs/notes/desktop/hypr.md': '# H\n\n`modules/home/desktop/hypr.nix`\n' });
    const run = () => {
      const { files, ...rest } = buildSourceIndex(root);
      return JSON.stringify({ ...rest, files: [...files] });
    };
    assert.equal(run(), run());
  });
});

// The real tree, which the derivation's src carries: the pages the feature exists for.
describe('the repo itself', () => {
  const root = path.resolve(import.meta.dirname, '../../..');
  const index = buildSourceIndex(root);
  const paths = (name: string) => page(index, name).files.map((f) => f.path);

  it('shows Hyprland its module, its Lua entry and its Lua modules', () => {
    const hypr = paths('notes/desktop/hypr.md');
    for (const rel of [
      'modules/home/desktop/hypr.nix',
      'modules/home/desktop/hypr/hyprland.lua',
      'modules/home/desktop/hypr/lua/appearance.lua',
      'modules/home/desktop/hypr/lua/keybinds.lua',
      'modules/home/desktop/hypr/lua/monitors.lua',
    ]) {
      assert.ok(hypr.includes(rel), rel);
    }
  });

  it('shows Vicinae, Quickshell and Caddy their modules', () => {
    assert.ok(paths('notes/desktop/vicinae.md').includes('modules/home/desktop/vicinae/default.nix'));
    assert.ok(paths('notes/desktop/quickshell.md').includes('modules/home/desktop/quickshell.nix'));
    assert.ok(paths('notes/network/caddy.md').includes('modules/nixos/services/caddy.nix'));
  });

  it('shows a page with no source an empty list', () => {
    assert.deepEqual(paths('notes/repo/license.md'), []);
  });

  it('publishes no credential, and only files some page shows', () => {
    assert.deepEqual(index.problems, []);
    for (const manifest of index.pages) {
      for (const related of manifest.files) {
        assert.ok(!related.path.startsWith('secrets/'), related.path);
        assert.ok(index.files.has(related.path), related.path);
      }
    }
  });
});
