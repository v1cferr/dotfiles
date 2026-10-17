// Every page of the site, from one route: the slug comes from lib/urls.ts, so the URLs are the
// ones MkDocs published and no reader's bookmark broke: docs/notes/repo/site.md
import { DocsBody, DocsPage, DocsTitle, EditOnGitHub } from 'fumadocs-ui/layouts/docs/page';
import { TOCPopover, TOCProvider } from 'fumadocs-ui/layouts/docs/page/slots/toc';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { HomeHero, HomeSections } from '../../components/home.tsx';
import { getMDXComponents } from '../../components/mdx.tsx';
import { SourceProvider } from '../../components/source/provider.tsx';
import { SourceTOC } from '../../components/source/side-panel.tsx';
import { BLOB_BASE } from '../../lib/repo.ts';
import { source } from '../../lib/source.ts';
import { tree } from '../../lib/tree.ts';
import { servedUrl } from '../../lib/urls.ts';

export default async function Page(props: PageProps<'/[[...slug]]'>) {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const MDX = page.data.body;

  // The home opens on an overview of the site, and its prose follows as on any other page.
  const isHome = page.url === '/';

  return (
    // The page's source files, keyed by page so a navigation starts clean. The right column is
    // Fumadocs' own TOC slot, given a second tab: docs/notes/repo/site-sources.md
    <SourceProvider key={page.path} page={page.path}>
      <DocsPage
        toc={page.data.toc}
        tableOfContent={{ style: 'clerk' }}
        slots={{ toc: { provider: TOCProvider, main: SourceTOC, popover: TOCPopover } }}
      >
        {isHome ? <HomeHero /> : <DocsTitle>{page.data.title}</DocsTitle>}
        {/* The file on GitHub, which is still where most of these pages get read. NOT Fumadocs'
            ViewOptionsPopover: it always carries a hardcoded link into a third-party AI service. */}
        <EditOnGitHub className="w-fit" href={`${BLOB_BASE}/docs/${page.path}`} />
        {isHome && <HomeSections tree={tree} />}
        <DocsBody>
          <MDX components={getMDXComponents()} />
        </DocsBody>
      </DocsPage>
    </SourceProvider>
  );
}

export function generateStaticParams() {
  return source.generateParams();
}

export async function generateMetadata(props: PageProps<'/[[...slug]]'>): Promise<Metadata> {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const { title, description } = page.data;
  // The SERVED url, with the slash: a canonical that redirects is a canonical that is ignored.
  const url = servedUrl(page.url);

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: { type: 'article', title, description, url },
    twitter: { card: 'summary', title, description },
  };
}
