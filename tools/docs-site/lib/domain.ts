// The origin, READ from docs/CNAME, which already owns the domain for GitHub Pages: writing it
// down a second time here is the drift rule 11 exists to stop.
import fs from 'node:fs';
import path from 'node:path';
import { DOCS_ROOT } from './docs-root.ts';

export const SITE_ORIGIN = `https://${fs.readFileSync(path.join(DOCS_ROOT, 'CNAME'), 'utf8').trim()}`;
