// The desktop's palette, worn by the site: palette.json is GENERATED from
// modules/home/desktop/palette-presets.nix, so the site owns no hex of its own: docs/notes/repo/site.md
import palette from '../palette.json' with { type: 'json' };

type Color = keyof typeof palette.colors;

const hex = (color: Color) => `#${palette.colors[color]}`;

// DARK is the palette as the desktop draws it. Fumadocs names a role, the palette names a color.
const DARK: Record<string, Color> = {
  background: 'bg',
  foreground: 'text',
  card: 'surface',
  'card-foreground': 'text',
  popover: 'surface',
  'popover-foreground': 'text',
  muted: 'surface',
  'muted-foreground': 'subtext',
  border: 'track',
  primary: 'accent',
  'primary-foreground': 'bg',
  secondary: 'surface',
  'secondary-foreground': 'text',
  accent: 'track',
  'accent-foreground': 'text',
  ring: 'accent',
};

/**
 * LIGHT is DERIVED, because no preset carries a light variant: the neutral preset stays, and only
 * the accent comes from the palette, darkened in oklab until it reads on white.
 */
const lightAccent = `color-mix(in oklab, ${hex('accent')} 72%, black)`;

/** The named hues too, for what draws with them (the graph's sections, the diagrams' accents). */
const hues = (Object.keys(palette.colors) as Color[])
  .map((color) => `--palette-${color}: ${hex(color)};`)
  .join('');

export const PALETTE_NAME = palette.name;

// `html` in front of each selector: the preset's own `:root` and `.dark` may load AFTER this.
export const PALETTE_CSS = [
  `html:root{${hues}--color-fd-primary:${lightAccent};--color-fd-ring:${lightAccent};}`,
  `html.dark{${Object.entries(DARK)
    .map(([role, color]) => `--color-fd-${role}:${hex(color)};`)
    .join('')}}`,
  // The sidebar's hover and selection sit one step above the page, as the desktop's lists do.
  `html.dark #nd-sidebar{--color-fd-secondary:${hex('track')};--color-fd-muted:${hex('track')};}`,
].join('\n');

// shiki ships an official theme for every curated preset; a base16 scheme falls back to GitHub's.
const CODE_THEMES: Record<string, string> = {
  'tokyo-night': 'tokyo-night',
  'catppuccin-mocha': 'catppuccin-mocha',
  'gruvbox-dark': 'gruvbox-dark-medium',
};

export const CODE_THEME_DARK = CODE_THEMES[palette.name] ?? 'github-dark';
