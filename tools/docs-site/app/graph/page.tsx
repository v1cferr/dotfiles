// /graph: the whole of docs/ as one map. The data is built here, at BUILD time, so the published
// page is static and reads the same markdown the pages do: docs/notes/repo/site.md
import { DocsDescription, DocsPage, DocsTitle } from 'fumadocs-ui/layouts/docs/page';
import type { Metadata } from 'next';
import { GraphView } from '../../components/graph-view.tsx';
import { GRAPH_URL, buildGraph } from '../../lib/graph.ts';
import { servedUrl } from '../../lib/urls.ts';

const title = 'Graph';
const description = 'Every page of these docs and the links between them, as one map.';

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: servedUrl(GRAPH_URL) },
  openGraph: { title, description, url: servedUrl(GRAPH_URL) },
};

export default function GraphPage() {
  const { nodes, links, groups } = buildGraph();
  return (
    <DocsPage full>
      <DocsTitle>{title}</DocsTitle>
      <DocsDescription>{description}</DocsDescription>
      <GraphView nodes={nodes} links={links} groups={groups} />
    </DocsPage>
  );
}
