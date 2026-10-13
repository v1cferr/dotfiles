// The top of `/`: a hero and a card per nav group. Every word is DERIVED, from site.json and the
// page tree, so the home owns no fact of its own; the prose below it is docs/README.md.
import type * as PageTree from 'fumadocs-core/page-tree';
import { Card, Cards } from 'fumadocs-ui/components/card';
import { buttonVariants } from 'fumadocs-ui/components/ui/button';
import Link from 'next/link';
import { REPO_URL, SITE_DESCRIPTION } from '../lib/repo.ts';
import { source } from '../lib/source.ts';
import { GRAPH_URL } from '../lib/graph.ts';
import { sectionHue } from '../lib/sections.ts';
import { docSlugs, servedUrl } from '../lib/urls.ts';
import site from '../site.json' with { type: 'json' };

/** The URL of a page under docs/, and a FAILED build when it is gone, never a dead button. */
function pageUrl(doc: string): string {
  const page = source.getPage(docSlugs(doc));
  if (!page) throw new Error(`the home links to docs/${doc}, which is not a page`);
  return page.url;
}

function pages(node: PageTree.Folder): PageTree.Item[] {
  const found = node.index ? [node.index] : [];
  for (const child of node.children) {
    if (child.type === 'page') found.push(child);
    else if (child.type === 'folder') found.push(...pages(child));
  }
  return found;
}

export function HomeHero() {
  // `github.com/v1cferr/dotfiles` reads as `v1cferr/dotfiles`, the name the repo goes by.
  const name = site.repo.split('/').slice(1).join('/');
  const links = [
    { label: 'Start here', href: '#start-here', primary: true },
    { label: 'Architecture', href: pageUrl('notes/repo/flake.md') },
    { label: 'Disaster recovery', href: pageUrl('guides/disaster-recovery.md') },
    { label: 'Graph', href: servedUrl(GRAPH_URL) },
    { label: 'GitHub', href: REPO_URL },
  ];

  return (
    <header className="not-prose flex flex-col gap-4 pb-2">
      <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{name}</h1>
      <p className="max-w-2xl text-lg text-fd-muted-foreground">{SITE_DESCRIPTION}</p>
      <p className="text-sm text-fd-muted-foreground">
        by{' '}
        <a href={site.author.url} className="font-medium text-fd-foreground hover:text-fd-primary">
          {site.author.name}
        </a>{' '}
        ·{' '}
        <a href={`https://github.com/${site.author.handle}`} className="hover:text-fd-primary">
          @{site.author.handle}
        </a>
      </p>
      <nav aria-label="Entry points" className="flex flex-wrap gap-2">
        {links.map((link) => (
          <Link
            key={link.label}
            href={link.href}
            className={buttonVariants({ variant: link.primary ? 'primary' : 'outline' })}
          >
            {link.label}
          </Link>
        ))}
      </nav>
    </header>
  );
}

/** One card per top-level group of the nav: its icon, how many pages, and the first few names. */
export function HomeSections({ tree }: { tree: PageTree.Root }) {
  const folders = tree.children.filter((node): node is PageTree.Folder => node.type === 'folder');

  return (
    <section aria-labelledby="explore" className="not-prose">
      <h2 id="explore" className="mb-4 text-xl font-semibold">
        Explore
      </h2>
      <Cards>
        {folders.map((folder) => {
          const items = pages(folder);
          // The group's own index page is the card itself, so the sample starts after it.
          const named = items.filter((item) => item !== folder.index);
          const names = named.slice(0, 4).map((item) => item.name);
          const rest = named.length - names.length;
          return (
            <Card
              key={folder.$id ?? String(folder.name)}
              // The section's own hue, the same one its pages wear on the graph.
              icon={<span style={{ color: `var(${sectionHue(String(folder.name))})` }}>{folder.icon}</span>}
              title={folder.name}
              href={items[0]?.url}
              description={`${items.length} pages · ${names.join(', ')}${rest > 0 ? `, +${rest}` : ''}`}
            />
          );
        })}
      </Cards>
    </section>
  );
}
