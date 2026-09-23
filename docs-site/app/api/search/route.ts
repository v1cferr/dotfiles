// The search INDEX, written into the static build as a file the browser downloads once. There is
// no server behind it, which is the only kind of search Pages can host: docs/notes/repo/site.md
import { createFromSource } from 'fumadocs-core/search/server';
import { source } from '../../../lib/source.ts';

export const revalidate = false;

export const { staticGET: GET } = createFromSource(source, { language: 'english' });
