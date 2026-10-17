// The publication policy and the manifest contract: traversal, exclusions and what a browser may
// fetch. Run by sources.nix on every build: docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  assetUrl,
  isPageManifest,
  isSourceToken,
  lineFromAnchor,
  pageManifestUrl,
} from '../lib/source-manifest.ts';
import {
  excludedBy,
  isCategory,
  languageOf,
  normalizeRepoPath,
  secretSignature,
} from '../lib/source-policy.ts';

describe('normalizeRepoPath', () => {
  it('collapses dots and repeated slashes into one spelling', () => {
    assert.equal(normalizeRepoPath('modules/./home//desktop/hypr.nix'), 'modules/home/desktop/hypr.nix');
    assert.equal(normalizeRepoPath('docs/notes/../../modules/x.nix'), 'modules/x.nix');
    assert.equal(normalizeRepoPath('modules/home/'), 'modules/home');
  });

  it('rejects anything that climbs out of the repo or is not a plain path', () => {
    for (const bad of [
      '../etc/passwd',
      'docs/../../x',
      '/etc/passwd',
      'C:\\Windows',
      'modules\\x.nix',
      'https://example.com/x',
      'file:///etc/passwd',
      'a b.nix',
      'x\u0000.nix',
      '~/x.nix',
      '',
      '.',
      './',
    ]) {
      assert.equal(normalizeRepoPath(bad), undefined, bad);
    }
  });
});

describe('excludedBy', () => {
  it('publishes source files under the roots', () => {
    for (const ok of [
      'modules/home/desktop/hypr.nix',
      'modules/home/desktop/hypr/lua/keybinds.lua',
      'modules/home/desktop/quickshell/bar/Bar.qml',
      'tools/docs-site/lib/urls.ts',
      'flake.nix',
      '.github/workflows/docs.yml',
    ]) {
      assert.equal(excludedBy(ok), undefined, ok);
    }
  });

  it('keeps secrets, credentials, lockfiles and the router mirror out', () => {
    for (const [path, reason] of [
      ['secrets/secrets.yaml', 'outside the published roots'],
      ['modules/nixos/core/secrets.nix', 'name matches secret'],
      ['modules/nixos/core/sync-secrets.sh', 'name matches secret'],
      ['hosts/cudy-wr3000/uci/wireless.conf', 'under hosts/cudy-wr3000/uci/'],
      ['modules/home/x/.env', 'name matches ^\\.env'],
      ['modules/home/x/prod.env', 'name matches \\.env$'],
      ['modules/home/x/id_ed25519', 'name matches ^id_(rsa|dsa|ecdsa|ed25519)'],
      ['modules/home/x/server.pem', 'name matches \\.(pem|key|p12|pfx|age|kdbx|gpg|asc)$'],
      ['tools/docs-site/pnpm-lock.yaml', 'name matches ^pnpm-lock\\.yaml$'],
      ['modules/x/package-lock.json', 'name matches ^package-lock\\.json$'],
      ['flake.lock', 'outside the published roots'],
      ['tools/docs-site/node_modules/x/index.js', 'under tools/docs-site/node_modules/'],
      ['modules/x/node_modules/y.js', 'inside node_modules/'],
      ['README.md', 'outside the published roots'],
      ['modules/home/x/logo.png', 'not a source language'],
      ['modules/../secrets/secrets.yaml', 'not a canonical repo path'],
    ]) {
      assert.equal(excludedBy(path!), reason, path);
    }
  });

  it('names the language a file is highlighted in', () => {
    assert.equal(languageOf('a/b.nix'), 'nix');
    assert.equal(languageOf('a/b.sh'), 'bash');
    assert.equal(languageOf('a/B.QML'), 'qml');
    assert.equal(languageOf('a/Makefile'), undefined);
    assert.equal(languageOf('a/.nix'), undefined);
  });
});

describe('isCategory', () => {
  it('tells a folder that groups modules from a module', () => {
    assert.ok(isCategory('modules/home'));
    assert.ok(isCategory('modules/home/desktop'));
    assert.ok(isCategory('tools'));
    assert.ok(!isCategory('modules/home/desktop/hypr'));
    assert.ok(!isCategory('tools/docs-site'));
  });
});

describe('secretSignature', () => {
  // Built at runtime, so this file never carries what it looks for.
  const dash = '-----';
  it('finds the shapes a credential has', () => {
    assert.equal(secretSignature(`${dash}BEGIN OPENSSH PRIVATE KEY${dash}\nabc`), 'a private key block');
    assert.equal(secretSignature(`AGE-SECRET-KEY-1${'Q'.repeat(58)}`), 'an age secret key');
    assert.equal(secretSignature(`x: ENC[AES256_GCM${',data:'}abc]`), 'a sops-encrypted value');
    assert.equal(secretSignature(`token=ghp_${'a'.repeat(36)}`), 'a GitHub token');
    assert.equal(secretSignature(`AKIA${'A'.repeat(16)}`), 'an AWS access key');
  });

  it('lets prose about secrets through', () => {
    assert.equal(secretSignature('sops.secrets.foo = { }; # read /run/secrets/foo'), undefined);
    assert.equal(secretSignature('a PRIVATE KEY is never committed'), undefined);
  });
});

describe('the manifest contract', () => {
  it('builds manifest URLs only for pages', () => {
    assert.equal(pageManifestUrl('notes/desktop/hypr.md'), '/_source/pages/notes/desktop/hypr.json');
    assert.equal(pageManifestUrl('README.md'), '/_source/pages/README.json');
    assert.equal(pageManifestUrl('../x.md'), undefined);
    assert.equal(pageManifestUrl('notes/x.nix'), undefined);
    assert.equal(pageManifestUrl('/etc/x.md'), undefined);
  });

  it('builds asset URLs only for content hashes', () => {
    assert.equal(assetUrl('0123456789abcdef.txt'), '/_source/files/0123456789abcdef.txt');
    assert.equal(assetUrl('../../index.html'), undefined);
    assert.equal(assetUrl('modules/x.nix'), undefined);
    assert.equal(assetUrl('0123456789ABCDEF.txt'), undefined);
  });

  it('tells a path-shaped inline code span from prose', () => {
    for (const yes of ['modules/home/desktop/hypr.nix', 'autostart.lua', 'hypr/', 'bar/TrayMenu.qml']) {
      assert.ok(isSourceToken(yes), yes);
    }
    for (const no of ['hyprctl reload', 'SUPER+M', 'enable', 'graphical-session.target ', '"a.nix"', '']) {
      assert.ok(!isSourceToken(no), no);
    }
  });

  it('reads the line of a GitHub anchor', () => {
    assert.equal(lineFromAnchor('#L12'), 12);
    assert.equal(lineFromAnchor('#L12-L20'), 12);
    assert.equal(lineFromAnchor('#L0'), undefined);
    assert.equal(lineFromAnchor('#the-lua-format'), undefined);
  });

  it('refuses a manifest that points outside the snapshot', () => {
    const file = {
      path: 'modules/x.nix',
      relation: 'direct',
      via: ['link'],
      sections: [],
      lang: 'nix',
      bytes: 1,
      lines: 1,
      asset: '0123456789abcdef.txt',
    };
    const manifest = { version: 1, page: 'a.md', files: [file], refs: {}, sections: {}, truncated: [] };
    assert.ok(isPageManifest(manifest));
    assert.ok(!isPageManifest({ ...manifest, files: [{ ...file, asset: '../../x.html' }] }));
    assert.ok(!isPageManifest({ ...manifest, files: [{ ...file, path: '../etc/passwd' }] }));
    assert.ok(!isPageManifest({ ...manifest, files: [{ ...file, relation: 'guess' }] }));
    assert.ok(!isPageManifest({ ...manifest, version: 2 }));
    assert.ok(!isPageManifest(null));
  });
});
