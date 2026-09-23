// Where docs/ is, resolved from the CWD because the bundler leaves no module path to resolve
// against. Next.js always runs from this directory, and docs/ is its sibling (rule 20).
import path from 'node:path';

export const DOCS_ROOT = path.resolve(process.cwd(), '../docs');
