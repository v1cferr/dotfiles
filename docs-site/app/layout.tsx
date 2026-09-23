// The root layout. The domain comes from docs/CNAME, which already owns it for GitHub Pages,
// instead of being written down a second time here (rule 11).
import fs from 'node:fs';
import path from 'node:path';
import type { Metadata } from 'next';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import type { ReactNode } from 'react';
import { baseOptions } from '../lib/layout.shared.tsx';
import { DOCS_ROOT } from '../lib/docs-root.ts';
import { buildPageTree } from '../lib/page-tree.ts';
import { SITE_DESCRIPTION, SITE_NAME } from '../lib/repo.ts';
import './global.css';
import { Provider } from './provider.tsx';

const domain = fs.readFileSync(path.join(DOCS_ROOT, 'CNAME'), 'utf8').trim();
const tree = buildPageTree(DOCS_ROOT);

export const metadata: Metadata = {
  metadataBase: new URL(`https://${domain}/`),
  title: { default: SITE_NAME, template: `%s - ${SITE_NAME}` },
  description: SITE_DESCRIPTION,
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="flex min-h-screen flex-col">
        <Provider>
          {/* The sidebar wraps EVERY route, 404 included: the docs are the whole site. */}
          <DocsLayout {...baseOptions()} tree={tree} sidebar={{ defaultOpenLevel: 1 }}>
            {children}
          </DocsLayout>
        </Provider>
      </body>
    </html>
  );
}
