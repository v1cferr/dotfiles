// It finishes the static export and then PROVES it, which is what `mkdocs build --strict` and a
// hand audit used to do between them. The three questions it answers: docs/notes/repo/site.md
//
//   1. the domain file GitHub Pages needs is in the output;
//   2. every page of docs/ is published at the URL it has always had, and nothing else is;
//   3. no published page fetches an asset from a third party (rule 20).
import fs from 'node:fs';
import path from 'node:path';
import { listPages } from '../lib/page-tree.ts';
import { docPathToUrl } from '../lib/urls.ts';

const ROOT = process.cwd();
const DOCS = path.resolve(ROOT, '../docs');
const OUT = path.resolve(ROOT, 'out');

// Next writes its own not-found route twice, and neither is a page of docs/.
const NOT_A_PAGE = new Set(['/404/', '/_not-found/']);

// A `rel` that describes the document instead of pulling a file in.
const METADATA_REL = /\brel\s*=\s*"(canonical|alternate|author|me|license|prev|next)"/i;
const ASSET_TAG = /<(script|link|img|source|iframe|video|audio)\b([^>]*)>/gi;
const ASSET_URL = /\b(?:src|href)\s*=\s*"(https?:\/\/[^"]+)"/i;
const CSS_URL = /(?:@import\s+|url\(\s*)["']?(https?:\/\/[^"')\s]+)/gi;

function walk(dir: string, match: (file: string) => boolean): string[] {
  const found: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) found.push(...walk(full, match));
    else if (match(full)) found.push(full);
  }
  return found;
}

function copyDomain(problems: string[]) {
  const cname = path.join(DOCS, 'CNAME');
  if (!fs.existsSync(cname)) {
    problems.push('docs/CNAME is gone, so the published site would lose its domain');
    return;
  }
  fs.copyFileSync(cname, path.join(OUT, 'CNAME'));
}

function checkUrls(problems: string[]) {
  const expected = new Set(listPages(DOCS).map(docPathToUrl));
  const published = new Set(
    walk(OUT, (file) => path.basename(file) === 'index.html').map(
      (file) => '/' + path.relative(OUT, path.dirname(file)).split(path.sep).filter(Boolean).join('/'),
    ),
  );

  for (const url of expected) if (!published.has(normalize(url))) problems.push(`${url} was not published`);
  for (const url of published) {
    const trailing = url === '/' ? '/' : `${url}/`;
    if (!expected.has(trailing) && !NOT_A_PAGE.has(trailing)) problems.push(`${trailing} has no page under docs/`);
  }
}

function normalize(url: string): string {
  return url === '/' ? '/' : url.replace(/\/$/, '');
}

function checkThirdParty(problems: string[]) {
  for (const file of walk(OUT, (f) => f.endsWith('.html'))) {
    const html = fs.readFileSync(file, 'utf8');
    for (const [, , attributes] of html.matchAll(ASSET_TAG)) {
      if (METADATA_REL.test(attributes)) continue;
      const external = ASSET_URL.exec(attributes);
      if (external) problems.push(`${path.relative(OUT, file)} fetches ${external[1]}`);
    }
  }

  for (const file of walk(OUT, (f) => f.endsWith('.css'))) {
    for (const [, url] of fs.readFileSync(file, 'utf8').matchAll(CSS_URL)) {
      problems.push(`${path.relative(OUT, file)} fetches ${url}`);
    }
  }
}

const problems: string[] = [];
copyDomain(problems);
checkUrls(problems);
checkThirdParty(problems);

if (problems.length > 0) {
  console.error(`\nfinish-export: ${problems.length} problem(s)\n`);
  for (const problem of problems.toSorted()) console.error(`  ${problem}`);
  process.exit(1);
}

console.log('finish-export: the URLs match docs/, and no page reaches for a third party');
