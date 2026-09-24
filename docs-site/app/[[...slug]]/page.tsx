// Every page of the site, from one route: the slug comes from lib/urls.ts, so the URLs are the
// ones MkDocs published and no reader's bookmark broke: docs/notes/repo/site.md
import { DocsBody, DocsPage, DocsTitle, EditOnGitHub } from 'fumadocs-ui/layouts/docs/page';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { getMDXComponents } from '../../components/mdx.tsx';
import { BLOB_BASE } from '../../lib/repo.ts';
import { source } from '../../lib/source.ts';
import { servedUrl } from '../../lib/urls.ts';

export default async function Page(props: PageProps<'/[[...slug]]'>) {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const MDX = page.data.body;

  return (
    <DocsPage toc={page.data.toc} tableOfContent={{ style: 'clerk' }}>
      <DocsTitle>{page.data.title}</DocsTitle>
      {/* The file on GitHub, which is still where most of these pages get read. NOT Fumadocs'
          ViewOptionsPopover: it always carries a hardcoded link into a third-party AI service. */}
      <EditOnGitHub className="w-fit" href={`${BLOB_BASE}/docs/${page.path}`} />
      <DocsBody>
        <MDX components={getMDXComponents()} />
      </DocsBody>
    </DocsPage>
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
