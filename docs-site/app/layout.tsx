// The root layout. The domain comes from docs/CNAME, which already owns it for GitHub Pages,
// instead of being written down a second time here (rule 11).
import fs from 'node:fs';
import path from 'node:path';
import type { Metadata } from 'next';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import type { ReactNode } from 'react';
import { baseOptions } from '../lib/layout.shared.tsx';
import { tree } from '../lib/page-tree.ts';
import { SITE_DESCRIPTION, SITE_NAME } from '../lib/repo.ts';
import './global.css';
import { Provider } from './provider.tsx';

// From the CWD, which is this directory: the bundler leaves no module path to resolve against.
const domain = fs.readFileSync(path.resolve(process.cwd(), '../docs/CNAME'), 'utf8').trim();

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
