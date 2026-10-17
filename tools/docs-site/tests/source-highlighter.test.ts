// The preview's highlighter carries exactly what the policy can publish and the palette can pick:
// a language left out would render plain, one too many is a chunk nobody loads.
// docs/notes/repo/site-sources.md
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { LANGUAGES, THEMES, highlighterFor } from '../components/source/highlighter.ts';
import { CODE_THEMES, CODE_THEME_LIGHT } from '../lib/palette.ts';
import { POLICY } from '../lib/source-policy.ts';

describe('the preview highlighter', () => {
  it('has a grammar for every language of the policy, and no other', () => {
    assert.deepEqual(Object.keys(LANGUAGES).toSorted(), [...new Set(Object.values(POLICY.extensions))].toSorted());
  });

  it('has every theme the palette can name, and no other', () => {
    const named = new Set([...Object.values(CODE_THEMES), 'github-dark', CODE_THEME_LIGHT]);
    assert.deepEqual(Object.keys(THEMES).toSorted(), [...named].toSorted());
  });

  it('loads every one of them, and highlights with what it loaded', async () => {
    await Promise.all([...Object.values(LANGUAGES), ...Object.values(THEMES)].map((load) => load()));
    const highlighter = await highlighterFor('nix', [CODE_THEME_LIGHT, 'tokyo-night']);
    const html = highlighter.codeToHtml('{ a = 1; }', {
      lang: 'nix',
      themes: { light: CODE_THEME_LIGHT, dark: 'tokyo-night' },
    });
    assert.match(html, /--shiki-dark:/);
  });
});
