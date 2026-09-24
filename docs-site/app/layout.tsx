// The root layout. The domain comes from docs/CNAME, which already owns it for GitHub Pages,
// instead of being written down a second time here (rule 11).
import type { Metadata } from 'next';
import { DocsLayout } from 'fumadocs-ui/layouts/docs';
import type { ReactNode } from 'react';
import { baseOptions } from '../lib/layout.shared.tsx';
import { DOCS_ROOT } from '../lib/docs-root.ts';
import { SITE_ORIGIN } from '../lib/domain.ts';
import { buildPageTree } from '../lib/page-tree.ts';
import { SITE_DESCRIPTION, SITE_NAME } from '../lib/repo.ts';
import './global.css';
import { Provider } from './provider.tsx';

const tree = buildPageTree(DOCS_ROOT);

// What every page inherits. A page overrides the title, the description and the canonical URL;
// the rest states the same thing on all 92 of them.
export const metadata: Metadata = {
  metadataBase: new URL(`${SITE_ORIGIN}/`),
  title: { default: SITE_NAME, template: `%s - ${SITE_NAME}` },
  description: SITE_DESCRIPTION,
  applicationName: SITE_NAME,
  // The pages are public and meant to be found: that is the whole reason the tree became a site.
  robots: { index: true, follow: true },
  openGraph: {
    type: 'website',
    siteName: SITE_NAME,
    locale: 'en_US',
    title: SITE_NAME,
    description: SITE_DESCRIPTION,
    url: '/',
  },
  // `summary` and not `summary_large_image`: there is no image to put in a card, and claiming
  // one that does not exist renders as a broken box.
  twitter: { card: 'summary', title: SITE_NAME, description: SITE_DESCRIPTION },
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
