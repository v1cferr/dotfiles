// THE SECTIONS and their hue: the graph's dots and the home's cards share one color per section,
// in the sidebar's order, from the palette's named hues: docs/notes/repo/site.md
import { navigation } from './navigation.ts';

/** A page outside every nav section (the home, the rules) belongs here. */
export const OVERVIEW = 'Overview';

export const SECTIONS = [OVERVIEW, ...navigation.flatMap((item) => ('section' in item ? [item.section] : []))];

const HUES = ['blue', 'cyan', 'green', 'yellow', 'orange', 'red', 'magenta', 'purple', 'teal', 'sky', 'pink'];

/** The palette variable a section is drawn in, e.g. `--palette-green`. */
export function sectionHue(section: string): string {
  const index = Math.max(0, SECTIONS.indexOf(section));
  return `--palette-${HUES[index % HUES.length]}`;
}
