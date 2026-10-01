// The sidebar's tree, built ONCE and read by the layout and the home, so both see the same nav.
import { sectionIcon } from '../components/section-icon.tsx';
import { DOCS_ROOT } from './docs-root.ts';
import { buildPageTree } from './page-tree.ts';

export const tree = buildPageTree(DOCS_ROOT, sectionIcon);
