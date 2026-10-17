// THE PUBLICATION POLICY: which repo files the site may copy into its source previews. Being in git
// is NOT enough, since the site republishes what it copies: docs/notes/repo/site-sources.md
//
// It reads one JSON file and nothing else, so bare node, the indexer and the tests share it.
import policy from '../source-policy.json' with { type: 'json' };

export const POLICY = {
  roots: policy.roots,
  extensions: policy.extensions as Record<string, string>,
  excludePrefixes: policy.excludePrefixes,
  excludeSegments: new Set(policy.excludeSegments),
  excludeNames: policy.excludeNames.map((pattern) => new RegExp(pattern, 'i')),
  // `*` is ONE segment: `modules/home/*` is every domain folder, and not what is inside them.
  categories: policy.categories.map(
    (glob) => new RegExp(`^${glob.replaceAll('.', '\\.').replaceAll('*', '[^/]+')}$`),
  ),
  maxBytes: policy.maxBytes,
  maxModuleFiles: policy.maxModuleFiles,
};

// A path character a repo file here never uses: a quote, a space, a backslash, a control byte.
const UNSAFE = /[^A-Za-z0-9_.@+/-]/;

/**
 * A repo-relative path in ONE canonical spelling, or undefined when it is not one: absolute, a URL,
 * a `..` that climbs out of the repo, or a character no file here has. Every path the indexer
 * stores and every path a reader's URL names goes through this, so traversal has one gate.
 */
export function normalizeRepoPath(input: string): string | undefined {
  if (input === '' || input.startsWith('/') || UNSAFE.test(input)) return;
  const segments: string[] = [];
  for (const segment of input.split('/')) {
    if (segment === '' || segment === '.') continue;
    if (segment === '..') {
      if (segments.length === 0) return;
      segments.pop();
    } else segments.push(segment);
  }
  return segments.length === 0 ? undefined : segments.join('/');
}

/** The extension the language is chosen by, lowercased, or '' for a file with none. */
function extension(path: string): string {
  const name = path.slice(path.lastIndexOf('/') + 1);
  const dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.slice(dot + 1).toLowerCase();
}

/**
 * Whether a folder only GROUPS modules (decision 0009's layout: `modules/home/desktop/`), so a page
 * naming it is pointing at a category and not at code to read.
 */
export function isCategory(dir: string): boolean {
  return POLICY.categories.some((pattern) => pattern.test(dir));
}

/** The shiki language of an eligible file. */
export function languageOf(path: string): string | undefined {
  return POLICY.extensions[extension(path)];
}

/** Why `path` must NOT be published, or undefined when the policy allows it. Canonical paths only. */
export function excludedBy(path: string): string | undefined {
  if (normalizeRepoPath(path) !== path) return 'not a canonical repo path';
  if (!POLICY.roots.some((root) => path === root || path.startsWith(`${root}/`))) {
    return 'outside the published roots';
  }
  const prefix = POLICY.excludePrefixes.find((p) => path.startsWith(p));
  if (prefix !== undefined) return `under ${prefix}`;
  const segments = path.split('/');
  const segment = segments.find((s) => POLICY.excludeSegments.has(s));
  if (segment !== undefined) return `inside ${segment}/`;
  const name = segments.at(-1)!;
  const pattern = POLICY.excludeNames.find((p) => p.test(name));
  if (pattern !== undefined) return `name matches ${pattern.source}`;
  if (languageOf(path) === undefined) return 'not a source language';
  return undefined;
}

// What a credential looks like INSIDE a file, as the last line of defense behind gitleaks. Each
// pattern carries a class or a count its own source text cannot satisfy, so this file passes it.
const SIGNATURES: [string, RegExp][] = [
  ['a private key block', /-----BEGIN [A-Z ]*PRIVATE KEY-----/],
  ['an age secret key', /AGE-SECRET-KEY-1[0-9A-Z]{58}/],
  ['a sops-encrypted value', /ENC\[AES256_GCM,data:/],
  ['a GitHub token', /\bgh[pousr]_[A-Za-z0-9]{36}\b/],
  ['an AWS access key', /\bAKIA[0-9A-Z]{16}\b/],
  ['a Slack token', /\bxox[abprs]-[A-Za-z0-9-]{10,}/],
];

/** What credential `content` appears to carry, or undefined. */
export function secretSignature(content: string): string | undefined {
  return SIGNATURES.find(([, pattern]) => pattern.test(content))?.[0];
}
