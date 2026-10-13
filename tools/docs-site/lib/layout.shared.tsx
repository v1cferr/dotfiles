// The options every layout shares: the title in the navbar, the graph, and the link to the repo.
import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { Waypoints } from 'lucide-react';
import { GRAPH_URL } from './graph.ts';
import { servedUrl } from './urls.ts';
import { REPO_URL, SITE_NAME } from './repo.ts';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: { title: SITE_NAME },
    githubUrl: REPO_URL,
    // The map of the whole tree, next to the search: the other way to find a page.
    links: [{ text: 'Graph', url: servedUrl(GRAPH_URL), icon: <Waypoints />, active: 'url' }],
  };
}
