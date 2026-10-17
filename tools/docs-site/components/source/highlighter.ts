// The preview's highlighter: shiki's core with the JavaScript regex engine, and ONLY the grammars
// the publication policy can hand it and the themes the palette can pick. Fumadocs' default
// imports the whole bundle, which wrote 330 chunk files no reader could ever request (measured
// 17/10/2026): docs/notes/repo/site-sources.md
import type { HighlighterCore, LanguageInput, ThemeInput } from 'shiki/core';

/** Every language in source-policy.json, each a chunk of its own. A test holds the two in step. */
export const LANGUAGES: Record<string, () => Promise<LanguageInput>> = {
  bash: () => import('shiki/langs/bash.mjs'),
  css: () => import('shiki/langs/css.mjs'),
  diff: () => import('shiki/langs/diff.mjs'),
  javascript: () => import('shiki/langs/javascript.mjs'),
  json: () => import('shiki/langs/json.mjs'),
  jsonc: () => import('shiki/langs/jsonc.mjs'),
  lua: () => import('shiki/langs/lua.mjs'),
  markdown: () => import('shiki/langs/markdown.mjs'),
  nix: () => import('shiki/langs/nix.mjs'),
  python: () => import('shiki/langs/python.mjs'),
  qml: () => import('shiki/langs/qml.mjs'),
  sql: () => import('shiki/langs/sql.mjs'),
  toml: () => import('shiki/langs/toml.mjs'),
  tsx: () => import('shiki/langs/tsx.mjs'),
  typescript: () => import('shiki/langs/typescript.mjs'),
  yaml: () => import('shiki/langs/yaml.mjs'),
};

/** Every theme lib/palette.ts can name. A test holds these in step too. */
export const THEMES: Record<string, () => Promise<ThemeInput>> = {
  'catppuccin-mocha': () => import('shiki/themes/catppuccin-mocha.mjs'),
  'github-dark': () => import('shiki/themes/github-dark.mjs'),
  'github-light': () => import('shiki/themes/github-light.mjs'),
  'gruvbox-dark-medium': () => import('shiki/themes/gruvbox-dark-medium.mjs'),
  'tokyo-night': () => import('shiki/themes/tokyo-night.mjs'),
};

let core: Promise<HighlighterCore> | undefined;

/**
 * The one highlighter, with `lang` and `themes` loaded BEFORE Fumadocs sees it: it only loads what
 * is missing, and a core highlighter cannot load a language by name.
 */
export async function highlighterFor(lang: string, themes: string[]): Promise<HighlighterCore> {
  core ??= Promise.all([import('shiki/core'), import('shiki/engine/javascript')]).then(
    ([{ createHighlighterCore }, { createJavaScriptRegexEngine }]) =>
      createHighlighterCore({ engine: createJavaScriptRegexEngine(), langs: [], themes: [] }),
  );
  const highlighter = await core;
  const loaded = new Set([...highlighter.getLoadedLanguages(), ...highlighter.getLoadedThemes()]);
  await Promise.all([
    !loaded.has(lang) && LANGUAGES[lang] && highlighter.loadLanguage(await LANGUAGES[lang]()),
    ...themes.filter((t) => !loaded.has(t) && THEMES[t]).map(async (t) => highlighter.loadTheme(await THEMES[t]!())),
  ]);
  return highlighter;
}
