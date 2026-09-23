// The repo and branch a link leaving docs/ is published against, READ from site.json so the
// canary workflow and this code cannot disagree. Why they are needed: docs/notes/repo/site.md
import site from '../site.json' with { type: 'json' };

export const BLOB_BASE = `https://${site.repo}/blob/${site.branch}`;
export const TREE_BASE = `https://${site.repo}/tree/${site.branch}`;
export const REPO_URL = `https://${site.repo}`;
export const SITE_NAME = site.name;
export const SITE_DESCRIPTION = site.description;
